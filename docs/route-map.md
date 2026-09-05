# Route Map

Real OpenStreetMap view of the active trip's route, with tappable per-day
and per-stop markers.

**Route:** `/map` (name `map`), third bottom tab.

**Key files:**
- `lib/features/map/map_screen.dart`
- `lib/features/map/widgets/map_location_sheet.dart` — the sheet opened by
  tapping a marker

## How it works

- Uses `flutter_map` with CARTO basemap tiles — `voyager` in light mode,
  `dark_all` in dark mode (`urlTemplate` switches on `Theme.of(context).brightness`).
  Tile usage requires visible attribution, shown as `_MapAttribution` in the
  bottom-right corner.
- Tiles are disk-cached (`flutter_map_cache` + a persistent `HiveCacheStore`)
  so previously-viewed areas render offline — see
  [Offline Support](./offline.md#map-tiles).
- Day markers (`_DayPin`, numbered, highlighted when active) come from each
  `ItineraryDay`'s `latitude`/`longitude` (its *starting* point, not the
  destination — see [planner.md](./planner.md#the-edge-function-schema)).
  Stop sub-markers (`_StopPin`) only render for stops with real coordinates
  (`TripStop.hasCoordinates`), since older/manually-edited trips may lack
  them.
- **There is no drawn route line** — a straight line between day points
  would misrepresent actual roads/ferries, so tapping a marker instead opens
  `map_location_sheet.dart`, which hands off to an external maps app for
  real turn-by-turn directions.
- The day chip row (shared with [Itinerary](./itinerary.md)) and
  `TripsStore.selectDay` stay in sync: selecting a chip flies the camera to
  that day's coordinates via a MobX `reaction` on `TripsStore.activeDay`.
  `_fitRoute` auto-fits the camera to every day's coordinates once the map
  is ready.
- The floating `_DayDetailCard` at the bottom shows the active day's title/
  distance/duration and a **View Day Details** button back to
  [Itinerary](./itinerary.md).
- Empty state ("Plan a trip to see its route here") shows when the active
  trip has no days with coordinates yet.
