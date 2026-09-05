# Trips (Home)

The signed-in landing tab: upcoming and past trip cards.

**Route:** `/home` (name `home`), first branch of the bottom
`StatefulShellRoute` (see `lib/shared/widgets/app_shell.dart`).

**Key files:**
- `lib/features/trips/trips_screen.dart` — the screen and its `_TripCard`
- `lib/features/trips/trips_store.dart` — MobX `TripsStore`
- `lib/features/trips/trips_repository.dart` — `Repository<Trip>`
  implementations (`SupabaseTripsRepository`, `LocalTripsRepository`)
- `lib/data/trip.dart` — the `Trip`/`ItineraryDay`/`TripStop`/`BudgetItem`/
  `Rider` freezed models

## How it works

- `TripsStore.initialize()` subscribes to `tripsRepository.watch()`
  (a realtime stream on Supabase, an in-memory stream locally) and exposes
  `upcomingTrips`/`pastTrips` as computed filters over `Trip.isPast`.
- Each `_TripCard` shows a `TripPhotoBanner` (see below), the trip name,
  `datesLabel · nights`, a `RiderAvatarRow`, and `distanceTotal`. Tapping a
  card calls `TripsStore.selectTrip(trip.id)` and pushes the
  [itinerary](./itinerary.md) route.
- `activeTrip`/`activeDay` (also on `TripsStore`) are the shared "currently
  viewed trip/day" state consumed by Itinerary and [Route Map](./route-map.md).
- When `Trip.status` is `done` or `skipped` (set from the
  [Itinerary](./itinerary.md#progress-done--skip) screen's Done/Skip
  actions), the card shows a small badge over the photo banner.
- Sign-out lives in the Home header (`CircleIconButton` → `AuthStore.signOut()`).

## Trip photos

`TripPhotoBanner` (`lib/shared/widgets/trip_photo_banner.dart`) renders a
real photo via a disk-cached `CachedNetworkImage(trip.coverImageUrl)` (see
[Offline Support](./offline.md#photo-images)) when the trip has one,
falling back to a striped placeholder — captioned with `trip.destination`
(or `trip.name` if destination is blank) — on a missing URL, offline, or a
failed load. `destination` and `coverImageUrl` are populated by the
`plan-trip` edge function during generation; see
[planner.md](./planner.md#destination-photos) for how that's wired (and
what's still a stub).

## Demo data & read-only trips

When Supabase isn't configured, `LocalTripsRepository` seeds itself with
`SampleTrips.palawan()` (`lib/data/sample_trips.dart`). The same trip also
ships as a shared demo row in the real Supabase `trips` table with
`user_id is null` — RLS lets every signed-in user read it, but only owners
can write, so the Itinerary screen treats the id
`palawan-coastal-loop` as read-only (hides Edit/Refine).

## Editing and refining a trip

Manual editing (`TripEditScreen`/`TripEditStore`) and AI-driven refinement
(the refine bottom sheet) are launched from the Itinerary screen's header
icons — documented in [itinerary.md](./itinerary.md#editing--refining).
