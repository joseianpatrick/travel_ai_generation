import 'package:kalsada/data/local/caching_repository.dart';
import 'package:kalsada/data/trip.dart';
import 'package:kalsada/data/trip_photo.dart';

/// Fans a sign-out event out to every offline cache that needs wiping, so a
/// shared device doesn't leave one account's cached rows/outbox queryable
/// after the next account signs in. Owns this one piece of sign-out policy
/// so [DependencyManager] stays a pure composition root — construct this,
/// wire [AuthStore.onSignedOut] to it, nothing more.
class OfflineCacheCoordinator {
  OfflineCacheCoordinator({this.tripsCache, this.photosCache});

  final CachingRepository<Trip>? tripsCache;
  final CachingRepository<TripPhoto>? photosCache;

  Future<void> clearForSignedOutUser(String? userId) async {
    if (userId == null) return;
    await Future.wait([
      if (tripsCache != null) tripsCache!.clearOwnerCache(userId),
      if (photosCache != null) photosCache!.clearOwnerCache(userId),
    ]);
  }
}
