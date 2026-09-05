# Offline Support

Trip/itinerary data and photo metadata are cached locally and stay
readable/editable offline, syncing back once the connection returns. Photo
*images* remain online-upload-only but are disk-cached after first view. Map
tiles are disk-cached too. AI trip generation still requires a live
connection.

**Key files:**
- `lib/data/local/app_database.dart` — drift schema (`CachedTrips`,
  `CachedTripPhotos`, `PendingMutations`) and the `AppDatabase` DAO
- `lib/data/local/caching_repository.dart` — `CachingRepository<T>`, the
  generic offline-caching `Repository<T>` decorator
- `lib/data/local/caching_trips_repository.dart` /
  `caching_photos_repository.dart` — `CachingTripsRepository` /
  `CachingPhotosRepository`, the entity-specific subclasses used by DI
- `lib/data/local/connectivity_service.dart` — `ConnectivityService`
  (`connectivity_plus` wrapper)
- `lib/data/local/tile_cache.dart` — builds the persistent `HiveCacheStore`
  backing map tile caching
- `lib/dependency/dependency_manager.dart` — wires all of the above

## How trip/photo data stays cached and synced

`CachingRepository<T>` implements the same `Repository<T>` interface as
`SupabaseTripsRepository`/`SupabasePhotosRepository`
(see [trips.md](./trips.md), [gallery.md](./gallery.md)), so
`TripsStore`/`PlannerStore`/`TripEditStore`/`PhotosStore` need no changes —
`DependencyManager.setTripStores()`/`setPhotoStores()` just wrap the
Supabase-backed repository with `CachingTripsRepository`/
`CachingPhotosRepository` whenever `SupabaseConfig.isConfigured` (the
`Local*Repository` dev-mode fallback is left untouched — it has no remote to
sync with).

- **`watch()`**: the drift cache is the only emission source — it yields
  current rows immediately on subscribe, then again on every write. A
  best-effort subscription to the remote stream writes each incoming doc
  into the cache (which re-emits automatically) and reconciles deletes
  (a cached id missing from the remote snapshot is removed *unless* there's
  a pending outbox entry for it, so a stale remote snapshot can't wipe an
  unsynced offline edit). Remote stream errors are swallowed, not surfaced —
  going offline looks like normal operation; the cache keeps serving.
- **`set()`/`delete()`**: write-through to the cache immediately (always
  succeeds locally), then attempt the remote call; on failure (or if already
  offline) the mutation is queued in the `PendingMutations` outbox instead.
- **`update()`**: read-modify-write against the cache (same merge semantics
  the Supabase repositories use), then delegates to `set()` — the outbox
  only ever replays whole-document `set`/`delete`, never a partial update.
- **`flushOutbox()`**: replays queued mutations in insertion order, stopping
  (not skipping) on the first failure so order and retry-ability survive to
  the next attempt. Triggered automatically whenever `ConnectivityService`
  reports back online (`startAutoFlush()`, called once per repository at DI
  wiring time). Concurrent requests share one flush, and every queued entry is
  revalidated under its document lock before replay.
- Conflict resolution is last-write-wins — this is a personal single-user
  app, no merge/CRDT logic.

## Map tiles

`MapScreen`'s `TileLayer` (see [route-map.md](./route-map.md)) wraps its
`tileProvider` in `flutter_map_cache`'s `CachedTileProvider`, backed by a
`HiveCacheStore` built once in `main.dart` before `runApp` and registered in
`sl`. Tiles already viewed while online render from disk when offline;
never-viewed tiles show blank, which is expected. `_resolveTileProvider()`
falls back to the plain network provider when no `HiveCacheStore` is
registered (keeps widget tests working without wiring the full DI graph).

## Photo images

`Image.network` was replaced with `cached_network_image`'s
`CachedNetworkImage` at every photo render site — `gallery_screen.dart`,
`itinerary_screen.dart`, `photo_viewer_dialog.dart`, and
`trip_photo_banner.dart` (whose striped-placeholder `errorBuilder`/
`loadingBuilder` map onto `CachedNetworkImage`'s `errorWidget`/`placeholder`).
Private Supabase object paths are resolved to short-lived signed URLs before
rendering; the image cache can continue serving bytes it has already seen.
Each site's existing `Image.file` fallback for local-dev on-device paths is
unchanged. Photo *uploads* are still online-only — offline
`PhotosStore.addPhoto` calls fail at the upload step before ever reaching the
repository, since only photo *metadata* is offline-cached per above.

## AI generation stays online-only

`PlanTripService` takes an optional `ConnectivityService` and throws the
existing `TripAgentException` immediately if offline when `planTrip()` is
called — both the [planner](./planner.md) and
[AI refine](./itinerary.md#editing--refining) already handle that exception
type, so no new UI was needed.

## Sign-out

Every cached row (`CachedTrips`, `CachedTripPhotos`, `PendingMutations`)
carries an `ownerId`, and cache primary keys/lookups include that owner, so
even identical document ids stay isolated. On top of that,
`AuthStore.onSignedOut` (set by
`DependencyManager.setSignOutHandling()`) wipes the outgoing user's cached
rows and outbox — see [auth.md](./auth.md#session-restore--route-guarding) —
so a shared device doesn't leave anything queryable for the next account.
The cleanup runs for explicit sign-out, session expiry, and external account
transitions observed through the auth stream.
