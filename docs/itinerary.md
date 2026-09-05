# Itinerary

Full day-by-day itinerary for one trip: day selector, stop timeline, and the
entry points for editing, AI refine, the route map, and the photo gallery.

**Route:** `/trip/:id` (name `itinerary`)

**Key files:**
- `lib/features/itinerary/itinerary_screen.dart` — day chips + stop timeline
- `lib/features/trips/trip_edit_screen.dart` /
  `lib/features/trips/trip_edit_store.dart` — manual editor
- `lib/features/trips/widgets/refine_sheet.dart` — AI-refine bottom sheet
- `lib/shared/widgets/day_chip_row.dart` — day selector, shared with
  [Route Map](./route-map.md)
- `lib/shared/widgets/photo_viewer_dialog.dart` — swipeable full-screen photo
  viewer with delete, shared with [Gallery](./gallery.md)

## How it works

- `ItineraryScreen` selects the trip (`TripsStore.selectTrip(tripId)`) and
  renders `TripsStore.activeDay`'s stats, title, `stay`/`stayPrice` (if the
  day has an overnight), and its `stops` as a vertical timeline
  (`_StopTimelineTile`). Switching the day chip re-renders instantly since
  everything comes from already-loaded `TripsStore` state.
- Each stop has a camera-icon thumbnail. Tapping it opens **Take Photo** /
  **Choose from Gallery** (`image_picker`) via `PhotosStore.addPhoto(...)`
  when the stop has no photos yet; once it has at least one, tapping instead
  opens `showPhotoViewer` over `PhotosStore.forStop(tripId, dayNumber,
  stopIndex, dayId, stopId)` — a swipeable full-screen view with a delete action
  (`PhotosStore.deletePhoto`) and an "add photo" shortcut back to the
  take/choose sheet. The thumbnail itself shows `PhotosStore.latestForStop(...)`
  with a count badge. See [gallery.md](./gallery.md) for the compiled,
  day-grouped view of the same photos.
- Header actions (left to right): back, **View on map** → pushes
  [Route Map](./route-map.md), **Trip photos** → pushes
  [Gallery](./gallery.md), then — only when `canEdit` — **Refine with AI**
  and **Edit trip**, plus the theme toggle.
- Each selected day includes **Find nearby food**. It opens an external maps
  search centered on that itinerary day's saved coordinates: Android offers
  installed maps apps (including Google Maps), while iOS opens Apple Maps.
  It does not request device location, call an AI model, or use a places API.

## Progress: done / skip

This is a planning app, not a booking one — there's no checkout. Instead:

- Each stop has two small **Done** / **Skip** buttons (visible when
  `canEdit`) that call `TripsStore.updateStopStatus(tripId, dayNumber,
  stopIndex, status)`, setting `TripStop.status` (`pending` / `done` /
  `skipped`). Tapping the same action again resets it to `pending`. `done`
  shows a green check on the timeline dot + a "Done" chip; `skipped`
  strikes through the stop's place/note and greys the dot.
- The bottom of the screen (previously "Book This Trip") is
  `_TripStatusFooter`: while the trip is `TripStatus.planning` it shows
  **Skip Trip** / **Mark Trip as Done** buttons calling
  `TripsStore.updateTripStatus(tripId, status)`; once set, it shows a status
  banner with an **Undo** button instead. The same toggle-to-reset rule
  applies. `Trip.status` also renders as a badge on the trip's card on
  [Home](./trips.md).

## Read-only trips

`canEdit = trip.id.isNotEmpty && trip.id != 'palawan-coastal-loop'` — the
shared seeded demo trip (`user_id is null` in Supabase) is readable by every
signed-in user but not writable under RLS, so its Edit/Refine icons are
hidden entirely rather than surfacing a save error. See
[trips.md](./trips.md#demo-data--read-only-trips).

## Editing & refining

Two independent ways to change a trip, both persisting under the trip's
existing id so the change flows back through the `TripsStore` stream:

- **Manual edit** (`TripEditScreen` → `TripEditStore.saveTrip`): a form over
  the trip's headline fields, riders, gear, and budget, plus per-day
  destination title / stay / stay price / stops. Route days' coordinates,
  distance, and duration are carried over unchanged — geocoding a
  hand-typed destination isn't implemented, so route edits go through AI
  refine instead.
- **AI refine** (`showRefineSheet` → `TripEditStore.refineTrip`): a free-text
  instruction (own suggestions: "Make it cheaper", "Add a rest day", "More
  food stops", "Make it more scenic") sent through the *same*
  `PlanTripService.planTrip()` used by [the planner](./planner.md), but with
  `baseTrip` set — the edge function is told to revise the existing JSON
  rather than generate from scratch, preserving the id and `isPast` flag.

Both surface `TripEditStore.errorMessage` on failure (`TripAgentException`
for refine failures, a generic message otherwise) via a snackbar.
