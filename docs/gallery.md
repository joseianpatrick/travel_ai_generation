# Gallery (Trip Photos)

Compiled, day-grouped photo gallery for one trip. User-captured photos are
tagged to a specific stop from the [Itinerary](./itinerary.md) screen and
compiled here — distinct from the AI-generated destination cover photo
described in [planner.md](./planner.md#destination-photos).

**Route:** `/trip/:id/gallery` (name `gallery`), reached from Itinerary's
photo-library header icon.

**Key files:**
- `lib/features/gallery/gallery_screen.dart` — the grid/viewer UI
- `lib/features/photos/photos_store.dart` — MobX `PhotosStore`
- `lib/features/photos/photos_repository.dart` — `Repository<TripPhoto>`
  implementations (`SupabasePhotosRepository`, `LocalPhotosRepository`)
- `lib/features/photos/photo_upload_service.dart` — Supabase Storage
  upload/delete
- `lib/data/trip_photo.dart` — the `TripPhoto` freezed model
- `lib/shared/widgets/photo_viewer_dialog.dart` — the shared full-screen
  viewer (`showPhotoViewer`), also used from [Itinerary](./itinerary.md)

## How it works

- Photos are added from **Itinerary**, not from this screen: tapping a
  stop's thumbnail opens a Take Photo / Choose from Gallery sheet
  (`image_picker`), which calls
  `PhotosStore.addPhoto(file, tripId, dayNumber, stopIndex, dayId, stopId)`.
  - When Supabase is configured, `PhotoUploadService.upload()` pushes the
    bytes to the private `trip-photos` storage bucket under
    `{userId}/{tripId}/{timestamp}.{ext}` and stores the object path. The UI
    obtains a short-lived signed URL when it displays the image.
    Apply `supabase/migrations/20260905000000_private_trip_photos.sql` through
    the normal Supabase migration workflow before deploying this client.
  - Otherwise (local dev fallback), the picked file's on-device path is
    stored directly — `GalleryScreen`/`ItineraryScreen` render it via
    `Image.file` vs. a disk-cached `CachedNetworkImage` based on whether the
    stored `url` starts with `http`. See
    [Offline Support](./offline.md#photo-images).
- `PhotosStore.groupedByDay(tripId, trip: trip)` resolves current day numbers
  from stable `dayId` values (with positional fallback for legacy rows);
  `countForStop`/
  `latestForStop`/`forStop` back the Itinerary thumbnail badge and per-stop
  viewer.
- Tapping a grid thumbnail opens `showPhotoViewer` with that day's full
  photo list and the tapped index, so you can swipe between the day's
  photos. Each photo has a **delete** action (confirm dialog →
  `PhotosStore.deletePhoto`), which first removes the underlying
  object via `PhotoUploadService`. If object deletion fails, metadata remains
  intact and the UI reports the failure so the user can retry without creating
  an unreachable orphan.
- The movie-camera icon in the header opens a **"Generate AI Video"**
  dialog that is an explicit stub — it states nothing is generated yet.

New photo rows reference stable `dayId` and `stopId` values, so deleting,
renumbering, or reordering itinerary entries does not retag existing photos.
`dayNumber` and `stopIndex` remain only as a compatibility fallback for rows
created by older app versions.
