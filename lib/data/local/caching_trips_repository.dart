import 'dart:convert';

import 'package:kalsada/data/local/app_database.dart';
import 'package:kalsada/data/local/caching_repository.dart';
import 'package:kalsada/data/trip.dart';

/// Binds [CachingRepository]'s generic callbacks to [Trip] and the
/// [AppDatabase]'s `CachedTrips` table.
class CachingTripsRepository extends CachingRepository<Trip> {
  CachingTripsRepository({
    required super.remote,
    required AppDatabase db,
    required super.connectivity,
    required super.ownerId,
  }) : super(
         watchCache: (owner) => db
             .watchTrips(owner)
             .map((rows) => rows.map(_tripFromRow).toList()),
         putCache: (owner, id, data) =>
             db.putTrip(id: id, ownerId: owner, data: data),
         deleteCache: db.deleteTrip,
         getCache: (owner, id) async {
           final row = await db.getTrip(owner, id);
           return row == null ? null : _tripFromRow(row);
         },
         allCacheIds: db.allTripIds,
         toMap: (trip) => trip.toMap(),
         fromMap: Trip.fromMap,
         idOf: (trip) => trip.id,
         enqueue: (owner, docId, op, payload) => db.enqueueMutation(
           collection: 'trips',
           docId: docId,
           ownerId: owner,
           op: op,
           payload: payload,
         ),
         clearMutation: (owner, docId, seq) => db.clearMutationIfCurrent(
           collection: 'trips',
           docId: docId,
           ownerId: owner,
           seq: seq,
         ),
         pendingMutations: (owner) async {
           final rows = await db.pendingFor('trips', owner);
           return rows.map(_asQueuedMutation).toList();
         },
         dequeue: db.deleteMutation,
         clearCacheForOwner: db.clearTripsForOwner,
         clearOutboxForOwner: (owner) => db.clearOutboxForOwner(owner),
         idsForOwner: db.allTripIds,
       );
}

Trip _tripFromRow(CachedTrip row) =>
    Trip.fromMap(jsonDecode(row.payload) as Map<String, Object?>);

QueuedMutation _asQueuedMutation(PendingMutation row) => QueuedMutation(
  seq: row.seq,
  docId: row.docId,
  op: row.op,
  payload: row.payload,
);
