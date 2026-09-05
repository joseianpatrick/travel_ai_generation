import 'dart:async';

import 'package:async/async.dart' show StreamQueue;
import 'package:base_project/data/local/app_database.dart';
import 'package:base_project/data/local/caching_repository.dart';
import 'package:base_project/data/local/caching_trips_repository.dart';
import 'package:base_project/data/local/connectivity_service.dart';
import 'package:base_project/data/repository/repository.dart';
import 'package:base_project/data/sample_trips.dart';
import 'package:base_project/data/trip.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_repository.dart';

/// Minimal, opt-in-flaky [ConnectivityService] double. Implementing (rather
/// than extending) is enough since `ConnectivityService`'s public surface is
/// just the two getters below.
class _FakeConnectivityService implements ConnectivityService {
  bool online = true;
  final StreamController<bool> _controller = StreamController.broadcast();

  @override
  Future<bool> get isOnline async => online;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  void setOnline(bool value) {
    online = value;
    _controller.add(value);
  }

  void close() => _controller.close();
}

/// Wraps [FakeRepository] so a single `set`/`delete`/`getById` call can be
/// made to fail on demand, for exercising [CachingRepository]'s failure
/// paths (flushOutbox's stop-on-first-failure, update()'s remote fallback).
class _FlakyRemote implements Repository<Trip> {
  _FlakyRemote(this._inner);

  final FakeRepository<Trip> _inner;
  bool failNextWrite = false;
  bool failNextGetById = false;

  void _maybeFail(bool trigger) {
    if (trigger) throw Exception('simulated remote failure');
  }

  @override
  Stream<List<Trip>> watch() => _inner.watch();

  @override
  Future<Trip?> getById(String id) async {
    final shouldFail = failNextGetById;
    failNextGetById = false;
    _maybeFail(shouldFail);
    return _inner.getById(id);
  }

  @override
  Future<void> create(String id, Trip value) async {
    final shouldFail = failNextWrite;
    failNextWrite = false;
    _maybeFail(shouldFail);
    await _inner.create(id, value);
  }

  @override
  Future<void> update(String id, Map<String, Object?> data) =>
      _inner.update(id, data);

  @override
  Future<void> delete(String id) async {
    final shouldFail = failNextWrite;
    failNextWrite = false;
    _maybeFail(shouldFail);
    await _inner.delete(id);
  }

  @override
  String newId() => _inner.newId();
}

class _BlockingRemote implements Repository<Trip> {
  final FakeRepository<Trip> _inner = FakeRepository<Trip>();
  final Completer<void> createStarted = Completer<void>();
  final Completer<void> releaseCreate = Completer<void>();
  int createCalls = 0;

  @override
  Stream<List<Trip>> watch() => _inner.watch();

  @override
  Future<Trip?> getById(String id) => _inner.getById(id);

  @override
  Future<void> create(String id, Trip value) async {
    createCalls++;
    if (!createStarted.isCompleted) createStarted.complete();
    await releaseCreate.future;
    await _inner.create(id, value);
  }

  @override
  Future<void> update(String id, Map<String, Object?> data) =>
      _inner.update(id, data);

  @override
  Future<void> delete(String id) => _inner.delete(id);

  @override
  String newId() => _inner.newId();

  void close() => _inner.close();
}

void main() {
  const ownerId = 'owner-1';
  late AppDatabase db;
  late FakeRepository<Trip> remote;
  late _FakeConnectivityService connectivity;
  late CachingTripsRepository repository;

  Trip trip(String id) => SampleTrips.palawan(id: id);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    remote = FakeRepository<Trip>();
    connectivity = _FakeConnectivityService();
    repository = CachingTripsRepository(
      remote: remote,
      db: db,
      connectivity: connectivity,
      ownerId: () => ownerId,
    );
  });

  tearDown(() async {
    repository.dispose();
    remote.close();
    connectivity.close();
    await db.close();
  });

  group('set', () {
    test(
      'write-through updates the cache immediately even while offline',
      () async {
        connectivity.setOnline(false);
        await repository.create('t1', trip('t1'));

        final cached = await repository.getById('t1');
        expect(cached, isNotNull);
        expect(cached!.id, 't1');
      },
    );

    test('online set reaches remote and leaves no queued mutation', () async {
      connectivity.setOnline(true);
      await repository.create('t1', trip('t1'));

      expect(await remote.getById('t1'), isNotNull);
      expect(await db.pendingFor('trips', ownerId), isEmpty);
    });

    test(
      'repeated offline edits to the same doc queue exactly one mutation',
      () async {
        connectivity.setOnline(false);
        await repository.create('t1', trip('t1').copyWith(name: 'first'));
        await repository.create('t1', trip('t1').copyWith(name: 'second'));
        await repository.create('t1', trip('t1').copyWith(name: 'third'));

        final pending = await db.pendingFor('trips', ownerId);
        expect(pending, hasLength(1));

        final cached = await repository.getById('t1');
        expect(cached!.name, 'third');
      },
    );
  });

  group('flushOutbox', () {
    test('replays a queued write to remote once back online', () async {
      connectivity.setOnline(false);
      await repository.create('t1', trip('t1'));
      expect(await remote.getById('t1'), isNull);

      connectivity.setOnline(true);
      await repository.flushOutbox();

      expect(await remote.getById('t1'), isNotNull);
      expect(await db.pendingFor('trips', ownerId), isEmpty);
    });

    test('stops on first failure and leaves the mutation queued', () async {
      final innerFake = FakeRepository<Trip>();
      final flakyRemote = _FlakyRemote(innerFake);
      final flakyRepo = CachingTripsRepository(
        remote: flakyRemote,
        db: db,
        connectivity: connectivity,
        ownerId: () => ownerId,
      );
      addTearDown(flakyRepo.dispose);
      addTearDown(innerFake.close);

      connectivity.setOnline(false);
      await flakyRepo.create('t1', trip('t1'));

      flakyRemote.failNextWrite = true;
      connectivity.setOnline(true);
      await flakyRepo.flushOutbox();

      expect(await db.pendingFor('trips', ownerId), hasLength(1));
    });

    test(
      'coalesces concurrent flushes instead of replaying stale work',
      () async {
        final blockingRemote = _BlockingRemote();
        final blockingRepository = CachingTripsRepository(
          remote: blockingRemote,
          db: db,
          connectivity: connectivity,
          ownerId: () => ownerId,
        );
        addTearDown(blockingRepository.dispose);
        addTearDown(blockingRemote.close);

        connectivity.online = false;
        await blockingRepository.create('t1', trip('t1'));
        connectivity.online = true;

        final first = blockingRepository.flushOutbox();
        await blockingRemote.createStarted.future;
        final second = blockingRepository.flushOutbox();
        blockingRemote.releaseCreate.complete();
        await Future.wait([first, second]);

        expect(blockingRemote.createCalls, 1);
        expect(await db.pendingFor('trips', ownerId), isEmpty);
      },
    );
  });

  test('cache rows with the same id remain isolated by owner', () async {
    await db.putTrip(
      id: 'same',
      ownerId: 'owner-a',
      data: trip('same').toMap(),
    );
    await db.putTrip(
      id: 'same',
      ownerId: 'owner-b',
      data: trip('same').copyWith(name: 'Owner B').toMap(),
    );

    expect(await db.getTrip('owner-a', 'same'), isNotNull);
    expect((await db.getTrip('owner-b', 'same'))!.payload, contains('Owner B'));

    await db.deleteTrip('owner-a', 'same');
    expect(await db.getTrip('owner-a', 'same'), isNull);
    expect(await db.getTrip('owner-b', 'same'), isNotNull);
  });

  test('an in-flight write stays bound to the owner that started it', () async {
    var activeOwner = 'owner-a';
    final blockingRemote = _BlockingRemote();
    final scopedRepository = CachingTripsRepository(
      remote: blockingRemote,
      db: db,
      connectivity: connectivity,
      ownerId: () => activeOwner,
    );
    addTearDown(scopedRepository.dispose);
    addTearDown(blockingRemote.close);

    connectivity.online = true;
    final write = scopedRepository.create('t1', trip('t1'));
    await blockingRemote.createStarted.future;
    activeOwner = 'owner-b';
    blockingRemote.releaseCreate.complete();
    await write;

    expect(await db.pendingFor('trips', 'owner-a'), isEmpty);
    expect(await db.getTrip('owner-a', 't1'), isNotNull);
    expect(await db.getTrip('owner-b', 't1'), isNull);
  });

  group('watch — remote to cache sync', () {
    test('docs written on remote flow into the local cache', () async {
      final dbQueue = StreamQueue(db.watchTrips(ownerId));
      addTearDown(dbQueue.cancel);
      expect(await dbQueue.next, isEmpty);

      final sub = repository.watch().listen((_) {});
      addTearDown(sub.cancel);

      await remote.create('t1', trip('t1'));

      final rows = await dbQueue.next;
      expect(rows.map((row) => row.id), contains('t1'));
    });

    test(
      'reconcile removes a cached doc once it no longer exists remotely',
      () async {
        await remote.create('t1', trip('t1'));
        final dbQueue = StreamQueue(db.watchTrips(ownerId));
        addTearDown(dbQueue.cancel);
        expect(await dbQueue.next, isEmpty);

        final sub = repository.watch().listen((_) {});
        addTearDown(sub.cancel);

        final afterInitialSync = await dbQueue.next;
        expect(afterInitialSync.map((row) => row.id), contains('t1'));

        await remote.delete('t1');
        final afterDelete = await dbQueue.next;
        expect(afterDelete.map((row) => row.id), isNot(contains('t1')));
      },
    );

    test(
      'reconcile does not delete a cached doc with an unsynced local write',
      () async {
        // Offline-created doc: cached + queued, but remote has never seen it.
        connectivity.setOnline(false);
        await repository.create('local-only', trip('local-only'));

        final dbQueue = StreamQueue(db.watchTrips(ownerId));
        addTearDown(dbQueue.cancel);
        final initial = await dbQueue.next;
        expect(initial.map((row) => row.id), contains('local-only'));

        // Subscribing triggers a reconcile pass against remote's (empty)
        // snapshot. Follow it with an unrelated remote write so there's a
        // deterministic table emission to assert against afterward — if the
        // pending doc had been wrongly reconciled away, it would already be
        // gone by the time this next emission lands.
        final sub = repository.watch().listen((_) {});
        addTearDown(sub.cancel);
        await remote.create('unrelated', trip('unrelated'));
        final afterReconcile = await dbQueue.next;

        expect(
          afterReconcile.map((row) => row.id),
          containsAll(['local-only', 'unrelated']),
        );
      },
    );

    test(
      'a remote snapshot does not overwrite a doc with an unsynced local edit',
      () async {
        await remote.create('t1', trip('t1').copyWith(name: 'server version'));
        final dbQueue = StreamQueue(db.watchTrips(ownerId));
        addTearDown(dbQueue.cancel);
        expect(await dbQueue.next, isEmpty);

        final sub = repository.watch().listen((_) {});
        addTearDown(sub.cancel);
        await dbQueue.next; // initial sync: t1 = "server version"

        connectivity.setOnline(false);
        await repository.create('t1', trip('t1').copyWith(name: 'local edit'));
        await dbQueue.next; // local edit lands in cache, queued in the outbox

        // Remote re-emits its full snapshot (still stale for t1, since the
        // local edit never reached it) because an unrelated doc changed.
        await remote.create('unrelated', trip('unrelated'));
        await dbQueue.next; // proves the snapshot above has been processed

        final t1 = await repository.getById('t1');
        expect(t1!.name, 'local edit');
      },
    );

    test(
      'a remote snapshot does not resurrect a doc with a pending local delete',
      () async {
        await remote.create('t1', trip('t1'));
        final dbQueue = StreamQueue(db.watchTrips(ownerId));
        addTearDown(dbQueue.cancel);
        expect(await dbQueue.next, isEmpty);

        final sub = repository.watch().listen((_) {});
        addTearDown(sub.cancel);
        await dbQueue.next; // initial sync

        connectivity.setOnline(false);
        await repository.delete('t1'); // queued; cache row removed
        await dbQueue.next;

        // Remote still has t1 (the delete hasn't synced) and re-emits
        // because an unrelated doc changed.
        await remote.create('unrelated', trip('unrelated'));
        await dbQueue.next;

        expect(await db.getTrip(ownerId, 't1'), isNull);
      },
    );
  });

  group('update', () {
    test('applies a field-level update against the cache', () async {
      await repository.create('t1', trip('t1'));
      await repository.update('t1', {'name': 'Renamed'});

      final updated = await repository.getById('t1');
      expect(updated!.name, 'Renamed');
    });

    test(
      'falls back to remote instead of silently dropping the write when not yet cached',
      () async {
        // Simulates a doc that synced from another device: it exists on
        // remote but this device's local cache has never seen it.
        await remote.create('t1', trip('t1'));

        await repository.update('t1', {'name': 'Renamed'});

        final updated = await repository.getById('t1');
        expect(updated, isNotNull);
        expect(updated!.name, 'Renamed');
      },
    );

    test('no-ops when the doc does not exist anywhere', () async {
      connectivity.setOnline(true);
      await repository.update('missing', {'name': 'x'});
      expect(await repository.getById('missing'), isNull);
    });

    test(
      'throws instead of silently dropping the write when offline and uncached',
      () async {
        connectivity.setOnline(false);
        expect(
          () => repository.update('missing', {'name': 'x'}),
          throwsA(isA<CacheUpdateException>()),
        );
      },
    );

    test('throws instead of silently dropping the write when the remote '
        'lookup fails and nothing is cached', () async {
      final innerFake = FakeRepository<Trip>();
      final flakyRemote = _FlakyRemote(innerFake);
      final flakyRepo = CachingTripsRepository(
        remote: flakyRemote,
        db: db,
        connectivity: connectivity,
        ownerId: () => ownerId,
      );
      addTearDown(flakyRepo.dispose);
      addTearDown(innerFake.close);

      connectivity.setOnline(true);
      flakyRemote.failNextGetById = true;

      expect(
        () => flakyRepo.update('missing', {'name': 'x'}),
        throwsA(isA<CacheUpdateException>()),
      );
    });
  });

  group('outbox seq safety', () {
    test('clearMutationIfCurrent only clears the matching seq, not a newer '
        'replacement', () async {
      final seqA = await db.enqueueMutation(
        collection: 'trips',
        docId: 't1',
        ownerId: ownerId,
        op: 'set',
        payload: {'name': 'A'},
      );
      final seqB = await db.enqueueMutation(
        collection: 'trips',
        docId: 't1',
        ownerId: ownerId,
        op: 'set',
        payload: {'name': 'B'},
      );
      expect(seqB, isNot(seqA)); // B already replaced A via upsert

      // Simulate A's stale, late-arriving remote success trying to clear
      // the mutation it created.
      await db.clearMutationIfCurrent(
        collection: 'trips',
        docId: 't1',
        ownerId: ownerId,
        seq: seqA,
      );

      // B's still-unsynced mutation must survive — seqA no longer
      // matches what's actually queued.
      final pending = await db.pendingFor('trips', ownerId);
      expect(pending, hasLength(1));
      expect(pending.single.seq, seqB);
    });
  });

  group('clearOwnerCache', () {
    test('wipes cached rows and queued mutations for the owner', () async {
      connectivity.setOnline(false);
      await repository.create('t1', trip('t1'));
      expect(await db.allTripIds(ownerId), isNotEmpty);
      expect(await db.pendingFor('trips', ownerId), isNotEmpty);

      await repository.clearOwnerCache(ownerId);

      expect(await db.allTripIds(ownerId), isEmpty);
      expect(await db.pendingFor('trips', ownerId), isEmpty);
    });
  });
}
