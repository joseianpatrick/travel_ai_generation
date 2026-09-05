import 'dart:convert';

import 'package:kalsada/data/local/app_database.dart';
import 'package:kalsada/data/local/caching_repository.dart';
import 'package:kalsada/data/trip_photo.dart';

/// Binds [CachingRepository]'s generic callbacks to [TripPhoto] and the
/// [AppDatabase]'s `CachedTripPhotos` table.
class CachingPhotosRepository extends CachingRepository<TripPhoto> {
  CachingPhotosRepository({
    required super.remote,
    required AppDatabase db,
    required super.connectivity,
    required super.ownerId,
  }) : super(
         watchCache: (owner) => db
             .watchPhotos(owner)
             .map((rows) => rows.map(_photoFromRow).toList()),
         putCache: (owner, id, data) => db.putPhoto(
           id: id,
           ownerId: owner,
           tripId: data['tripId'] as String? ?? '',
           data: data,
         ),
         deleteCache: db.deletePhoto,
         getCache: (owner, id) async {
           final row = await db.getPhoto(owner, id);
           return row == null ? null : _photoFromRow(row);
         },
         allCacheIds: db.allPhotoIds,
         toMap: (photo) => photo.toMap(),
         fromMap: TripPhoto.fromMap,
         idOf: (photo) => photo.id,
         enqueue: (owner, docId, op, payload) => db.enqueueMutation(
           collection: 'photos',
           docId: docId,
           ownerId: owner,
           op: op,
           payload: payload,
         ),
         clearMutation: (owner, docId, seq) => db.clearMutationIfCurrent(
           collection: 'photos',
           docId: docId,
           ownerId: owner,
           seq: seq,
         ),
         pendingMutations: (owner) async {
           final rows = await db.pendingFor('photos', owner);
           return rows.map(_asQueuedMutation).toList();
         },
         dequeue: db.deleteMutation,
         clearCacheForOwner: db.clearPhotosForOwner,
         clearOutboxForOwner: (owner) => db.clearOutboxForOwner(owner),
         idsForOwner: db.allPhotoIds,
       );
}

TripPhoto _photoFromRow(CachedTripPhoto row) =>
    TripPhoto.fromMap(jsonDecode(row.payload) as Map<String, Object?>);

QueuedMutation _asQueuedMutation(PendingMutation row) => QueuedMutation(
  seq: row.seq,
  docId: row.docId,
  op: row.op,
  payload: row.payload,
);
