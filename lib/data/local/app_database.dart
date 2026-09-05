import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Cached trip documents, one row per [Trip.id]. [payload] is the full
/// `Trip.toMap()` JSON-encoded; [ownerId] scopes rows to the signed-in user
/// so a sign-out/sign-in on the same device never mixes accounts' data.
class CachedTrips extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {ownerId, id};
}

/// Cached trip-photo-metadata documents, one row per [TripPhoto.id].
/// [tripId] is a real indexed column since [PhotosStore.forTrip] and
/// [PhotosStore.groupedByDay] filter by trip.
@TableIndex(name: 'idx_cached_photos_trip_id', columns: {#tripId})
class CachedTripPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get tripId => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {ownerId, id};
}

/// One pending offline write per row, replayed in insertion order once
/// connectivity returns. [collection] discriminates trips vs photos since
/// this table is intentionally generic (unlike the two above).
class PendingMutations extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get collection => text()(); // 'trips' | 'photos'
  TextColumn get docId => text()();
  TextColumn get ownerId => text()();
  TextColumn get op => text()(); // 'set' | 'delete'
  TextColumn get payload => text().nullable()(); // null for 'delete'
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [CachedTrips, CachedTripPhotos, PendingMutations])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.alterTable(TableMigration(cachedTrips));
        await migrator.alterTable(TableMigration(cachedTripPhotos));
      }
    },
  );

  // --- Trips ---

  Stream<List<CachedTrip>> watchTrips(String ownerId) =>
      (select(cachedTrips)..where((t) => t.ownerId.equals(ownerId))).watch();

  Future<CachedTrip?> getTrip(String ownerId, String id) =>
      (select(cachedTrips)
            ..where((t) => t.ownerId.equals(ownerId) & t.id.equals(id)))
          .getSingleOrNull();

  Future<void> putTrip({
    required String id,
    required String ownerId,
    required Map<String, Object?> data,
  }) => into(cachedTrips).insertOnConflictUpdate(
    CachedTripsCompanion.insert(
      id: id,
      ownerId: ownerId,
      payload: jsonEncodeMap(data),
      updatedAt: DateTime.now(),
    ),
  );

  Future<void> deleteTrip(String ownerId, String id) => (delete(
    cachedTrips,
  )..where((t) => t.ownerId.equals(ownerId) & t.id.equals(id))).go();

  Future<Set<String>> allTripIds(String ownerId) async {
    final rows =
        await (selectOnly(cachedTrips)
              ..addColumns([cachedTrips.id])
              ..where(cachedTrips.ownerId.equals(ownerId)))
            .get();
    return rows.map((row) => row.read(cachedTrips.id)!).toSet();
  }

  Future<void> clearTripsForOwner(String ownerId) =>
      (delete(cachedTrips)..where((t) => t.ownerId.equals(ownerId))).go();

  // --- Photos ---

  Stream<List<CachedTripPhoto>> watchPhotos(String ownerId) => (select(
    cachedTripPhotos,
  )..where((t) => t.ownerId.equals(ownerId))).watch();

  Future<CachedTripPhoto?> getPhoto(String ownerId, String id) =>
      (select(cachedTripPhotos)
            ..where((t) => t.ownerId.equals(ownerId) & t.id.equals(id)))
          .getSingleOrNull();

  Future<void> putPhoto({
    required String id,
    required String ownerId,
    required String tripId,
    required Map<String, Object?> data,
  }) => into(cachedTripPhotos).insertOnConflictUpdate(
    CachedTripPhotosCompanion.insert(
      id: id,
      ownerId: ownerId,
      tripId: tripId,
      payload: jsonEncodeMap(data),
      updatedAt: DateTime.now(),
    ),
  );

  Future<void> deletePhoto(String ownerId, String id) => (delete(
    cachedTripPhotos,
  )..where((t) => t.ownerId.equals(ownerId) & t.id.equals(id))).go();

  Future<Set<String>> allPhotoIds(String ownerId) async {
    final rows =
        await (selectOnly(cachedTripPhotos)
              ..addColumns([cachedTripPhotos.id])
              ..where(cachedTripPhotos.ownerId.equals(ownerId)))
            .get();
    return rows.map((row) => row.read(cachedTripPhotos.id)!).toSet();
  }

  Future<void> clearPhotosForOwner(String ownerId) =>
      (delete(cachedTripPhotos)..where((t) => t.ownerId.equals(ownerId))).go();

  // --- Outbox ---

  /// Queues [docId]'s mutation, replacing any prior unsynced row for the
  /// same document so a doc edited multiple times offline keeps exactly one
  /// outbox entry (the latest state) instead of accumulating stale ones that
  /// would otherwise be replayed in order ahead of it. Returns the new row's
  /// `seq`, so a caller can later clear *this specific* mutation rather than
  /// "whatever happens to be queued for this doc" — see [clearMutationIfCurrent].
  Future<int> enqueueMutation({
    required String collection,
    required String docId,
    required String ownerId,
    required String op,
    Map<String, Object?>? payload,
  }) => transaction(() async {
    await clearMutationFor(
      collection: collection,
      docId: docId,
      ownerId: ownerId,
    );
    return into(pendingMutations).insert(
      PendingMutationsCompanion.insert(
        collection: collection,
        docId: docId,
        ownerId: ownerId,
        op: op,
        payload: Value(payload == null ? null : jsonEncodeMap(payload)),
        createdAt: DateTime.now(),
      ),
    );
  });

  Future<List<PendingMutation>> pendingFor(String collection, String ownerId) =>
      (select(pendingMutations)
            ..where(
              (m) =>
                  m.collection.equals(collection) & m.ownerId.equals(ownerId),
            )
            ..orderBy([(m) => OrderingTerm.asc(m.seq)]))
          .get();

  Future<void> deleteMutation(int seq) =>
      (delete(pendingMutations)..where((m) => m.seq.equals(seq))).go();

  /// Clears any queued mutation for [docId] regardless of which one — used
  /// internally by [enqueueMutation] to upsert, where replacing whatever is
  /// there is exactly the point.
  Future<void> clearMutationFor({
    required String collection,
    required String docId,
    required String ownerId,
  }) =>
      (delete(pendingMutations)..where(
            (m) =>
                m.collection.equals(collection) &
                m.docId.equals(docId) &
                m.ownerId.equals(ownerId),
          ))
          .go();

  /// Clears [docId]'s queued mutation only if it's still the row with [seq]
  /// — i.e. only if no newer local write has since replaced it. Call this
  /// (not [clearMutationFor]) after a remote write succeeds: if a newer edit
  /// already superseded this one locally (new seq) while the remote call was
  /// in flight, this is a safe no-op and the newer mutation stays queued for
  /// its own retry, instead of a stale success wiping out a newer pending
  /// write that never actually reached remote.
  Future<void> clearMutationIfCurrent({
    required String collection,
    required String docId,
    required String ownerId,
    required int seq,
  }) =>
      (delete(pendingMutations)..where(
            (m) =>
                m.collection.equals(collection) &
                m.docId.equals(docId) &
                m.ownerId.equals(ownerId) &
                m.seq.equals(seq),
          ))
          .go();

  Future<void> clearOutboxForOwner(String ownerId) =>
      (delete(pendingMutations)..where((m) => m.ownerId.equals(ownerId))).go();
}

String jsonEncodeMap(Map<String, Object?> data) => jsonEncode(data);

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'kalsada.sqlite'));
  return NativeDatabase.createInBackground(file);
});
