import 'dart:async';
import 'dart:convert';

import 'package:kalsada/data/local/connectivity_service.dart';
import 'package:kalsada/data/repository/repository.dart';

/// A queued offline write, decoupled from drift's generated row class so
/// this decorator's public surface doesn't leak the local persistence
/// engine to callers outside `lib/data/local/`.
class QueuedMutation {
  const QueuedMutation({
    required this.seq,
    required this.docId,
    required this.op,
    required this.payload,
  });

  final int seq;
  final String docId;
  final String op;
  final String? payload;
}

/// Thrown by [CachingRepository.update] when it can't determine the
/// document's current state to merge the partial update against — distinct
/// from a confirmed "doc doesn't exist anywhere", which is a legitimate
/// no-op (matching SupabaseXRepository.update()'s convention).
class CacheUpdateException implements Exception {
  const CacheUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Offline-caching decorator: wraps a remote [Repository<T>] with a
/// drift-backed local cache and an outbox for offline writes. Every store
/// still only sees a `Repository<T>` — this is a drop-in replacement for the
/// remote repository at the DI wiring point. One generic implementation is
/// shared by trips and photos (via the `build...Repository` factories in
/// `caching_trips_repository.dart` / `caching_photos_repository.dart`) to
/// avoid duplicating the retry/outbox/stream-merge logic per entity.
class CachingRepository<T> implements Repository<T> {
  CachingRepository({
    required this.remote,
    required this.connectivity,
    required this.ownerId,
    required this.watchCache,
    required this.putCache,
    required this.deleteCache,
    required this.getCache,
    required this.allCacheIds,
    required this.toMap,
    required this.fromMap,
    required this.idOf,
    required this.enqueue,
    required this.clearMutation,
    required this.pendingMutations,
    required this.dequeue,
    required this.clearCacheForOwner,
    required this.clearOutboxForOwner,
    required this.idsForOwner,
  });

  final Repository<T> remote;
  final ConnectivityService connectivity;
  final String Function() ownerId;
  final Stream<List<T>> Function(String ownerId) watchCache;
  final Future<void> Function(
    String ownerId,
    String id,
    Map<String, Object?> data,
  )
  putCache;
  final Future<void> Function(String ownerId, String id) deleteCache;
  final Future<T?> Function(String ownerId, String id) getCache;
  final Future<Set<String>> Function(String ownerId) allCacheIds;
  final Map<String, Object?> Function(T value) toMap;
  final T Function(Map<String, Object?> map) fromMap;
  final String Function(T value) idOf;
  final Future<int> Function(
    String ownerId,
    String docId,
    String op,
    Map<String, Object?>? payload,
  )
  enqueue;
  final Future<void> Function(String ownerId, String docId, int seq)
  clearMutation;
  final Future<List<QueuedMutation>> Function(String ownerId) pendingMutations;
  final Future<void> Function(int seq) dequeue;
  final Future<void> Function(String ownerId) clearCacheForOwner;
  final Future<void> Function(String ownerId) clearOutboxForOwner;
  // Explicit owner parameters let cleanup and in-flight operations remain
  // attached to the session that started them after auth state changes.
  final Future<Set<String>> Function(String ownerId) idsForOwner;

  StreamSubscription<bool>? _connectivitySub;
  final Map<String, Future<void>> _flushes = {};

  final Map<String, Future<void>> _docLocks = {};

  /// Serializes every read/write this class does for [id] — across `set`,
  /// `delete`, `flushOutbox`'s replay, and the remote listener's write-back
  /// — so two of them never race a network call for the same document.
  /// Different documents remain fully concurrent. A failed [action] never
  /// wedges the queue: the next caller for the same id still runs.
  Future<R> _withDocLock<R>(
    String owner,
    String id,
    Future<R> Function() action,
  ) {
    final key = '$owner\u0000$id';
    final previous = _docLocks[key] ?? Future<void>.value();
    final result = previous.then((_) => action());
    late final Future<void> chain;
    chain = result.then((_) {}, onError: (_) {}).whenComplete(() {
      // Only drop the entry if no later caller has chained onto it.
      if (identical(_docLocks[key], chain)) _docLocks.remove(key);
    });
    _docLocks[key] = chain;
    return result;
  }

  @override
  Stream<List<T>> watch() {
    late final StreamController<List<T>> controller;
    StreamSubscription<List<T>>? cacheSub;
    StreamSubscription<List<T>>? remoteSub;
    StreamSubscription<bool>? reconnectSub;
    late String watchOwner;
    var cancelled = false;
    var resubscribing = false;
    // Identifies the current listen cycle. Bumped on every onListen/onCancel
    // so a subscribeRemote() call started under an earlier cycle can detect,
    // after its await, that it's been superseded and bail out instead of
    // installing a subscription for a cycle nobody is listening to anymore.
    Object? cycle;
    // Serializes remote-snapshot processing: the listener below is async but
    // Stream.listen doesn't await it, so back-to-back snapshots could
    // otherwise interleave — an older snapshot's _reconcileDeletes running
    // after a newer snapshot's putCache would delete a doc the newer
    // snapshot just wrote. Chaining each snapshot onto the last forces them
    // to apply in arrival order.
    var snapshotChain = Future<void>.value();

    Future<void> subscribeRemote() async {
      if (cancelled || resubscribing) return;
      final myCycle = cycle;
      resubscribing = true;
      try {
        await remoteSub?.cancel();
        if (cancelled || !identical(myCycle, cycle)) return;
        remoteSub = remote.watch().listen(
          (remoteDocs) {
            snapshotChain = snapshotChain.then((_) async {
              // Bail if this listen cycle has since been torn down: a
              // snapshot queued right before cancellation (e.g. sign-out,
              // which cancels this subscription and then wipes the owner's
              // cache via clearOwnerCache in the same call chain) must not
              // keep writing afterward and resurrect data the cache clear
              // just removed. Rechecked after every await below since
              // cancellation can land mid-loop, not just before it starts.
              if (cancelled) return;
              try {
                // Never let a remote snapshot clobber a doc with an unsynced
                // local write — it may be older than what's cached (the
                // snapshot could predate this device's own edit), and a
                // pending delete would otherwise get silently resurrected.
                final pendingIds = (await pendingMutations(
                  watchOwner,
                )).map((m) => m.docId).toSet();
                for (final doc in remoteDocs) {
                  if (cancelled) return;
                  final id = idOf(doc);
                  if (pendingIds.contains(id)) continue;
                  await _withDocLock(
                    watchOwner,
                    id,
                    () => putCache(watchOwner, id, toMap(doc)),
                  );
                }
                if (cancelled) return;
                await _reconcileDeletes(
                  watchOwner,
                  remoteDocs.map(idOf).toSet(),
                );
              } catch (_) {
                // Swallowed for the same reason as onError below: the cache
                // keeps serving silently rather than surfacing a load error
                // just because one snapshot failed to apply.
              }
            });
          },
          onError: (Object _, StackTrace _) {
            // A stream error here (e.g. offline) is swallowed rather than
            // surfaced — the cache keeps serving silently, which is the
            // whole point of offline support; TripsStore/PhotosStore
            // shouldn't show a load-error banner just because the remote is
            // unreachable. But a faulted subscription is otherwise inert
            // forever, so re-subscribe whenever connectivity is regained.
          },
          onDone: () {
            // The remote stream can also complete gracefully (e.g. a
            // realtime channel closing) without connectivity ever toggling
            // — resubscribe here too, not just on reconnect, so the cache
            // doesn't go silently stale until the next connectivity blip.
            subscribeRemote();
          },
        );
      } finally {
        // Only this cycle's own call may clear the flag. If `cycle` has
        // since moved on, a fresher call for the new cycle may already be
        // in flight and own `resubscribing` — clearing it here would let a
        // third caller slip past the top guard and race that fresher call
        // to install a second, untracked remote subscription.
        if (identical(myCycle, cycle)) resubscribing = false;
      }
    }

    controller = StreamController<List<T>>.broadcast(
      onListen: () {
        // A broadcast stream re-fires onListen if a new listener attaches
        // after every previous one detached (which set cancelled = true in
        // onCancel below) — reset it so remote sync actually restarts
        // instead of subscribeRemote() silently no-oping forever.
        cancelled = false;
        // Also clear a stale `resubscribing` left over from a subscribeRemote()
        // call that was still in-flight when the last listener detached —
        // otherwise this cycle's subscribeRemote() call below would see it
        // still true and silently no-op, leaving remote sync dead until the
        // next connectivity change. The in-flight call is harmless once it
        // resumes: `cycle` is fresh by then, so its post-await check fails
        // and it exits without touching `remoteSub`.
        resubscribing = false;
        cycle = Object();
        watchOwner = ownerId();
        // The cache is the only emission source: it fires current rows
        // immediately on subscribe and again on every write (including
        // writes made by the remote listener below), so callers get
        // "cache now, then live updates" for free with no separate merge
        // step.
        cacheSub = watchCache(watchOwner).listen(controller.add);
        // Best-effort remote subscription layered on top.
        subscribeRemote();
        // Re-establish the remote subscription every time connectivity is
        // regained, so a subscription that faulted while offline (or on a
        // transient error) doesn't leave the cache permanently stale.
        reconnectSub = connectivity.onStatusChange.listen((online) {
          if (online) subscribeRemote();
        });
      },
      onCancel: () {
        cancelled = true;
        cycle = null;
        cacheSub?.cancel();
        remoteSub?.cancel();
        reconnectSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Removes cached docs that no longer exist remotely, unless there's an
  /// unsynced local write for that id — otherwise a stale remote snapshot
  /// could wipe an offline-created/edited document before it ever syncs.
  Future<void> _reconcileDeletes(String owner, Set<String> remoteIds) async {
    final cachedIds = await allCacheIds(owner);
    final pendingIds = (await pendingMutations(
      owner,
    )).map((m) => m.docId).toSet();
    for (final id in cachedIds) {
      if (!remoteIds.contains(id) && !pendingIds.contains(id)) {
        await _withDocLock(owner, id, () => deleteCache(owner, id));
      }
    }
  }

  @override
  Future<T?> getById(String id) async {
    final owner = ownerId();
    final cached = await getCache(owner, id);
    if (await connectivity.isOnline) {
      try {
        final fresh = await remote.getById(id);
        if (fresh != null) await putCache(owner, id, toMap(fresh));
        return fresh ?? cached;
      } catch (_) {
        return cached;
      }
    }
    return cached;
  }

  @override
  Future<void> create(String id, T value) => _create(ownerId(), id, value);

  Future<void> _create(String owner, String id, T value) =>
      _withDocLock(owner, id, () async {
        // Mark dirty *before* writing the cache row, not after: this closes the
        // window where a concurrent remote reconcile (see _reconcileDeletes)
        // could see the freshly-cached row without yet seeing a pending outbox
        // entry for it and wrongly conclude it was deleted remotely.
        final seq = await enqueue(owner, id, 'set', toMap(value));
        await putCache(
          owner,
          id,
          toMap(value),
        ); // write-through: always succeeds locally
        if (await connectivity.isOnline) {
          try {
            await remote.create(id, value);
            // Only clear *this* mutation, not "whatever is queued for id" — a
            // newer edit may have already replaced it (different seq) while
            // this remote call was in flight, and that newer write still needs
            // its own retry.
            await clearMutation(owner, id, seq);
          } catch (_) {
            // leave enqueued for the next flushOutbox/startAutoFlush retry
          }
        }
      });

  @override
  Future<void> update(String id, Map<String, Object?> data) async {
    final owner = ownerId();
    // Same read-modify-write merge SupabaseXRepository.update() does, but
    // against the cache, then delegate to set() so the outbox only ever
    // replays whole-document set/delete, never a partial update.
    final cached = await getCache(owner, id);
    if (cached != null) {
      await _create(owner, id, fromMap({...toMap(cached), ...data}));
      return;
    }
    // Nothing cached — could mean the doc genuinely doesn't exist, or just
    // that this device hasn't synced it down yet (fresh install, doc
    // created elsewhere). Ask remote to tell the two apart instead of
    // silently dropping the update either way.
    if (!await connectivity.isOnline) {
      throw const CacheUpdateException(
        'Cannot apply update: not cached locally and device is offline.',
      );
    }
    final T? fresh;
    try {
      fresh = await remote.getById(id);
    } catch (error) {
      throw CacheUpdateException(
        'Cannot apply update: not cached locally and remote lookup failed '
        '($error).',
      );
    }
    if (fresh == null) return; // remote confirms it genuinely doesn't exist
    // set() below does its own write-through putCache of the merged result,
    // so there's no need to cache `fresh` separately first.
    await _create(owner, id, fromMap({...toMap(fresh), ...data}));
  }

  @override
  Future<void> delete(String id) {
    final owner = ownerId();
    return _withDocLock(owner, id, () async {
      // Mark dirty before removing from cache — see the comment in set().
      final seq = await enqueue(owner, id, 'delete', null);
      await deleteCache(owner, id);
      if (await connectivity.isOnline) {
        try {
          await remote.delete(id);
          await clearMutation(
            owner,
            id,
            seq,
          ); // see set() for why this is seq-scoped
        } catch (_) {
          // leave enqueued for the next flushOutbox/startAutoFlush retry
        }
      }
    });
  }

  @override
  String newId() => remote.newId();

  /// Starts listening for connectivity-regained events and flushes the
  /// outbox automatically. Call once after construction.
  void startAutoFlush() {
    _connectivitySub = connectivity.onStatusChange.listen((online) {
      if (online) unawaited(flushOutbox());
    });
  }

  /// Replays queued mutations in insertion order; stops (not skips) on the
  /// first failure so order and retry-ability are preserved for next time.
  /// Each replay is doc-locked (see [_withDocLock]) so it can't race a
  /// concurrent set()/delete() call — or another flushOutbox() call — for
  /// the same document.
  Future<void> flushOutbox() {
    final owner = ownerId();
    final existing = _flushes[owner];
    if (existing != null) return existing;
    final flush = _flushPendingMutations(owner);
    _flushes[owner] = flush;
    return flush.whenComplete(() {
      if (identical(_flushes[owner], flush)) _flushes.remove(owner);
    });
  }

  Future<void> _flushPendingMutations(String owner) async {
    while (true) {
      final pending = await pendingMutations(owner);
      if (pending.isEmpty) return;
      final mutation = pending.first;
      try {
        await _withDocLock(owner, mutation.docId, () async {
          // The snapshot above may be stale if a normal create/delete
          // completed before this document lock was acquired. Re-read and
          // only replay the still-current mutation for this document.
          final current = (await pendingMutations(
            owner,
          )).where((candidate) => candidate.docId == mutation.docId);
          if (current.isEmpty) return;
          final latest = current.last;
          if (latest.op == 'set') {
            final payload = latest.payload;
            if (payload == null) {
              await dequeue(latest.seq);
              return;
            }
            final value = fromMap(jsonDecode(payload) as Map<String, Object?>);
            await remote.create(latest.docId, value);
          } else {
            await remote.delete(latest.docId);
          }
          await dequeue(latest.seq);
        });
      } catch (_) {
        return;
      }
    }
  }

  /// Deletes every cached row and outbox entry for [ownerId] — call on
  /// sign-out so a shared device leaves nothing recoverable for the next
  /// account.
  Future<void> clearOwnerCache(String ownerId) async {
    // Clear the outbox first, not last: flushOutbox() isn't torn down on
    // sign-out and can be triggered independently (e.g. a connectivity
    // event), so it may read this owner's pending mutations and start
    // replaying them to remote at any time. Clearing the outbox before
    // doing anything else shrinks — though doesn't eliminate, since a read
    // already in flight isn't retracted — the window in which such a replay
    // can start after this call believes sign-out cleanup is done.
    await clearOutboxForOwner(ownerId);
    // Route each delete through _withDocLock: a remote snapshot's write-back
    // (see watch()'s snapshotChain) can still be mid-flight for one of these
    // ids when sign-out fires, since nothing else forces that write to
    // finish before this runs. Locking each id first makes any such write
    // finish before its delete does, instead of racing it and potentially
    // resurrecting the row afterward.
    final ids = await idsForOwner(ownerId);
    for (final id in ids) {
      await _withDocLock(ownerId, id, () => deleteCache(ownerId, id));
    }
    // Bulk sweep as a backstop for anything outside that snapshot (e.g. a
    // row that only existed too briefly to be caught above, including one
    // created by a local set() call that started after the snapshot).
    await clearCacheForOwner(ownerId);
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
