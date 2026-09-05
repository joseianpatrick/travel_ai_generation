# Plan a Trip

Conversational trip generation, rendered with
[GenUI](https://pub.dev/packages/genui) (Google's generative-UI SDK for
Flutter) and backed by a live Gemini Supabase Edge Function.

**Route:** `/plan` (name `plan`), second bottom tab.

**Key files:**
- `lib/features/planner/planner_screen.dart` — the conversation UI
- `lib/features/planner/planner_store.dart` — MobX `PlannerStore`
  (idle/generating/complete lifecycle)
- `lib/features/planner/planner_options.dart` — `PlannerOptions` (travel
  mode, expressways, group size, pace, lodging budget, day count)
- `lib/features/planner/widgets/trip_options_sheet.dart` — the options
  picker sheet
- `lib/features/planner/kalsada_catalog.dart` — the GenUI widget vocabulary
  (`TripOverviewCard`, `RouteCard`, `BudgetCard`, `GearChecklistCard`)
- `lib/features/planner/trip_agent_transport.dart` — base `Transport` +
  `SimulatedTripAgentTransport` (local/test fallback)
- `lib/features/planner/gemini_trip_agent_transport.dart` —
  `GeminiTripAgentTransport`, the live transport
- `lib/features/planner/plan_trip_service.dart` — `PlanTripService`, the
  single call site for the `plan-trip` edge function (shared with AI refine)
- `supabase/functions/plan-trip/` — the edge function itself
  (`gemini.ts`, `photo.ts`, `index.ts`)

## How it works

1. User picks a suggestion chip or types a prompt in `_PromptBar`.
   `PlannerStore.startGeneration()` flips `phase` to `generating` and clears
   any previous trip/error.
2. `PlannerScreen` sends the prompt through a GenUI `Conversation`
   (`_conversation.sendRequest`), which delegates to whichever
   `TripAgentTransport` was registered in DI.
3. The transport (`emitTripSurfaces` in `trip_agent_transport.dart`) streams
   four surfaces in order — overview, route, budget, gear — each rendered by
   the matching `CatalogItem` in `kalsada_catalog.dart`, with a
   `stepDelay` pause between them to mimic model streaming. A closing
   `summary` string arrives as free text.
4. On completion, `PlannerScreen` reads `transport.lastGeneratedTrip` and
   calls `PlannerStore.completeGeneration(trip)`, which assigns an id (if
   the transport didn't supply one) and **persists it via the shared
   `Repository<Trip>`** — the trip appears on [Home](./trips.md)
   immediately, not just in the conversation.
5. `PlannerOptions` (the pill above the prompt bar) are attached as
   `pendingOptions` on the transport before each send and forwarded to the
   edge function as generation constraints.

## Live vs. simulated transport

`DependencyManager.setPlannerTransport()` registers a factory (new instance
per `PlannerScreen`, so each conversation owns/disposes its own transport):

- `SupabaseConfig.isConfigured` → `GeminiTripAgentTransport`, which calls
  `PlanTripService.planTrip()` → the deployed `plan-trip` edge function
  (Google Gemini, forced function-calling; see `gemini.ts`).
- otherwise → `SimulatedTripAgentTransport`, which fabricates
  `SampleTrips.palawan()` locally. Also the deterministic double used in
  widget tests.

`PlanTripService.planTrip()` is the one place a `plan-trip` JSON response
turns into a `Trip` (`Trip.fromMap`) — it throws `TripAgentException` on any
network/parsing failure or an incomplete trip (no name / no days), which the
screen surfaces as a snackbar and routes back to `PlannerStore.failGeneration`.
Generation is online-only: `planTrip()` throws the same exception immediately
if `ConnectivityService` reports offline, before ever calling the edge
function — see [Offline Support](./offline.md#ai-generation-stays-online-only).

## The edge function schema

`gemini.ts` forces the model to call a `create_trip`
tool whose shape mirrors `lib/data/trip.dart` almost exactly: `name`,
`destination`, `datesLabel`, `nights`, `distanceTotal`, `totalPerRider`,
`totalGroup`, `days[]` (each with real lat/long for its start point, plus
`stops[]` with their own coordinates, `stay`/`stayPrice`), `budgetItems[]`,
`gearItems[]`, `riders[]` (initials only — `colorValue` is assigned
client-side from a fixed palette), and a closing `summary`. The system
prompt defaults to Philippines destinations, enforces real/plottable
coordinates, and dictates exact string formats (dates, currency, distances).

Secrets (Supabase Dashboard → Edge Functions → Secrets):
`GOOGLE_STUDIO_FREE_KEY` (required), `GEMINI_MODEL` (optional).

## Destination photos

`destination` is a clean location string (e.g. `"Palawan, Philippines"`),
kept separate from the creative `name` so it can drive a photo lookup.
`supabase/functions/plan-trip/photo.ts` exports `fetchDestinationPhoto()`,
wired into `gemini.ts` to attach `coverImageUrl` to the
returned trip — but the actual provider call is **not implemented yet**
(it always returns `null`, and generation never fails because of it). To
finish this: pick a photo API, add its key as an edge function secret, and
fill in the fetch in `photo.ts`. See [trips.md](./trips.md#trip-photos) for
how the client renders whatever URL comes back.

## Refine vs. generate

AI refine (from the Itinerary screen) reuses the exact same
`PlanTripService.planTrip()` call with a `baseTrip` attached — the edge
function is told to revise the existing JSON rather than start fresh. See
[itinerary.md](./itinerary.md#editing--refining).
Stable day/stop ids and completed/skipped stop state are included in that
schema; the client also preserves them when matching an unchanged stop, so a
model omission cannot silently reset progress or photo associations.
