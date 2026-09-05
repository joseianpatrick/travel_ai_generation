# Kalsada Code Review — 2026-07-28

Full-codebase pass (~9,500 lines, 55 files) against this project's MobX / DI / Clean
Architecture conventions (`flutter-reviewer` skill) plus a UI/UX pass over every
screen. Includes `flutter analyze` and `flutter test` results.

**Verdict: approve with fixes.** Architecture and offline-sync engineering are
excellent — the one blocker is a test-suite regression, not a product bug.

**Update (2026-07-29): all Blockers, Should-fix, and Nit items below have been
addressed** (RLS in #5 remains a manual verification step, not a code change).
`flutter analyze` is clean and `flutter test` is 112/112 passing (103 pre-existing
+ additional coverage added since). See the ✅ note under each item.

---

## Blockers

### 1. 9 of 103 widget tests fail — `.toUpperCase()` styling shipped without updating the tests it broke

✅ **Fixed.** Added `test/support/finders.dart` with a `findLabel()` helper that
matches `Text` widgets case-insensitively, and swapped it in wherever a test
was asserting on a `PrimaryButton`/`AuthTextField` label. This is the more
robust fix from the two options below — assertions now read as the actual
copy and won't break again on the next styling tweak.
`flutter test` → **9 failing**, all for the same reason: `PrimaryButton`
(`lib/shared/widgets/primary_button.dart:58`) and `AuthTextField`
(`lib/features/auth/widgets/auth_widgets.dart:54`) render their label text
via `.toUpperCase()`, but the tests still search for the mixed-case source
strings (`find.text('Sign In')`, `find.text('Next')`, `find.text('Get Started')`,
`find.text('Mark Trip as Done')`, `find.text('View Full Itinerary')`,
`find.text('Email address')`, `find.text('Password')`).

Failing tests:
- `test/features/auth/sign_in_screen_test.dart` — all 3 tests
- `test/features/planner/planner_screen_test.dart` — "tapping a suggestion shows the user bubble and generates"
- `test/features/itinerary/itinerary_screen_test.dart` — "renders day 1 timeline and switches days", "marking the trip done shows a status banner with undo"
- `test/features/onboarding/onboarding_screen_test.dart` — all 3 tests

**Fix**: update the affected `find.text(...)` calls to match the rendered
uppercase strings (or use a case-insensitive `find.textContaining` /
`RegExp`, or a `Key`-based finder so the assertion doesn't depend on display
casing at all — the latter is more robust against future copy changes).
This is mechanical (~9 one-line edits) but the suite has been silently
red until now, which means real regressions in these five flows could ship
undetected. Worth a quick look at CI to see how this passed review.

---

## Should fix

### 2. `RiderAvatarRow` — O(n²) `indexOf` inside its own build loop
`lib/shared/widgets/rider_avatar_row.dart:67-71`
```dart
for (final child in children)
  Transform.translate(
    offset: Offset(shift * children.indexOf(child), 0),
    ...
```
Works today only because each `Container` is a distinct object (identity
equality), but it's fragile and does a linear scan per item. Use an indexed
loop instead:
```dart
for (final (i, child) in children.indexed)
  Transform.translate(offset: Offset(shift * i, 0), child: child),
```
Rider lists are small (≤8) so there's no real perf impact — flagging for
correctness clarity, not speed.

✅ **Fixed** — `rider_avatar_row.dart` now uses `children.indexed`.

### 3. Status badges bypass the design system's color tokens
- `lib/features/trips/trips_screen.dart:202` (`_TripStatusBadge`) hardcodes
  `Colors.green` / `Colors.black87` instead of `context.kalsada`.
- `lib/features/itinerary/itinerary_screen.dart:569,572` hardcodes
  `Colors.green` / `Colors.orange` for the same "done/skipped" concept that
  `colors.ter` and the theme's semantic colors are used for elsewhere.

Every other screen in the app routes color through `KalsadaColors`
(`context.kalsada`), including dark-mode variants. These hardcoded values
won't adapt if the palette changes and don't have a dark-mode counterpart
(`Colors.black87` on a dark card background is a real contrast risk — worth
checking in dark mode). Add `done` / `skipped` / `warning` semantic colors to
`KalsadaColors` and use them here instead.

✅ **Fixed** — added `success`/`warning` fields (light + dark variants) plus a
`KalsadaColors.statusOverlay` constant to `kalsada_theme.dart` for the trip
badge that overlays a photo (not a card surface, so it intentionally doesn't
vary by theme). Both call sites now route through `context.kalsada`.

### 4. Unused dependencies in `pubspec.yaml`
`lottie`, `shared_preferences`, and `dio` (direct import, distinct from
`dio_cache_interceptor` which *is* used) have no references anywhere in
`lib/`. `assets/lottie/splash_logo.json` is bundled but the splash screen
(`lib/features/splash/splash_screen.dart`) builds its animation entirely
with `AnimationController`/`CustomPaint`, not `Lottie`. Either wire these up
or drop them — unused deps inflate app size and the dependency-audit
surface for no benefit.

✅ **Fixed** — removed `lottie`, `shared_preferences`, and the direct `dio`
dependency (still available transitively via `dio_cache_interceptor`) from
`pubspec.yaml`, and deleted the orphaned `assets/lottie/` folder + its
`flutter.assets` entry.

### 5. Confirm Supabase RLS before shipping
`lib/data/supabase/supabase_config.dart` commits a real project URL and
publishable key. That's expected — publishable keys are meant to be
client-visible, same as Firebase's config — but it means the *only* thing
standing between any API client and your `trips` / `trip_photos` tables and
the `trip-photos` storage bucket is Row-Level Security. Worth a deliberate
check (via `supabase inspect` or the dashboard) that:
- `trips` / `trip_photos` RLS policies scope reads/writes to the row's
  owner (there's a `user_id` column noted in the `trip_photos` schema
  comment, but the config doesn't show a matching policy or an
  owner column on `trips`).
- the `trip-photos` bucket, despite being `public: true` for read access,
  restricts *writes* to the authenticated owner.

This isn't a code defect so much as an unverified assumption the code
relies on — flagging because `caching_repository.dart`'s owner-scoped local
cache implies the team is already thinking carefully about per-user data
isolation, and it'd be a shame for that discipline to stop at the client.

⚠️ **Not fixed — requires a manual/infra check, not a code change.** Verify
directly against the live Supabase project (dashboard or `supabase inspect`)
before shipping.

---

## Nits

- `lib/features/itinerary/itinerary_screen.dart:456-467` (`_pickImage`) is a
  `StatelessWidget` method capturing `Navigator.of(context)` before an
  `await`, then calling `navigator.canPop()` / `.pop()` after. Since it's
  stateless there's no `mounted` guard available; the `canPop()` check
  covers the common case, but if the sheet's context is fully disposed
  mid-upload this could still throw. Low risk given the sheet stays open
  through the upload, but worth a `try`/`catch` or converting the sheet to a
  minimal `StatefulWidget` if this ever bites in practice.
  ✅ **Fixed** — wrapped the post-await `navigator.pop()` in a `try`/`catch`.
- `lib/features/trips/trip_edit_screen.dart:53-56` falls back to
  `tripsStore.activeTrip` if the requested `tripId` isn't found in
  `tripsStore.trips` — on a cold deep link before the trips stream has
  loaded, this could silently open the *wrong* trip for editing rather than
  showing a loading/error state. Only reachable today via a direct deep
  link (in-app navigation always loads trips first), so low priority.
  ✅ **Fixed** — falls back to `Trip.empty()` instead of `activeTrip` (never
  silently substitutes a different trip), and pops back with a "Trip not
  found." snackbar if the requested id truly isn't in the store.
- Both `planner_screen.dart` and `trip_edit_screen.dart`/`refine_sheet.dart`
  define their own private `_Stepper`/`_StepButton` /
  `_SectionLabel` widgets with identical implementations
  (`planner_screen.dart` doesn't, but `trip_options_sheet.dart` and
  `trip_edit_screen.dart` both do, near-verbatim). Small enough that it's a
  judgment call, but if a fourth copy shows up, promote to
  `shared/widgets/`.
  ✅ **Fixed** — `_Stepper`/`_StepButton` were byte-for-byte identical, so
  promoted to `shared/widgets/number_stepper.dart` as `NumberStepper`
  (renamed to avoid shadowing Material's own `Stepper`). `_SectionLabel` was
  left alone in both files — it's not actually duplicated, the two versions
  use different type styles (mono/uppercase vs. plain caption).

---

## What's working well (worth preserving as the app grows)

- **Offline sync (`lib/data/local/caching_repository.dart`)** is the
  standout piece of engineering here: doc-level locking, seq-scoped outbox
  clearing (so a stale remote-write success can't clobber a newer local
  edit), snapshot-chain serialization to avoid interleaved writes, and
  careful sign-out cache scoping. The comments explain *why*, not *what*,
  throughout — exactly the right altitude.
- **Clean/SOLID boundaries hold**: no screen imports a `*_repository.dart`
  directly, stores are Flutter-free, `DependencyManager` is a pure
  composition root, and every `Repository<T>` implementation (Local +
  Supabase, ×2 entities) honors the full interface with no
  `UnimplementedError` traps.
- **MobX usage is correct**: every observable mutation is inside `@action`
  or `runInAction`, stream subscriptions are cancelled before
  re-subscribing (`initialize()` on every store), and `dispose()` is wired
  everywhere it's needed.
- **`dart analyze` is clean** — zero issues.
- **Error handling is consistently user-safe**: `AuthFailure`,
  `TripAgentException`, and `CacheUpdateException` all separate
  log-worthy detail from user-facing copy, and every async action that can
  fail (sign-in, plan-trip, refine, save) surfaces a specific message
  instead of a generic "something went wrong."
- **UI/UX consistency**: a single `PrimaryButton` and `AuthTextField` used
  everywhere, tooltips on every icon-only button (accessible by default via
  `Tooltip`'s semantics), theme-aware color tokens used almost universally,
  loading/error/empty states present on every data-driven screen (Trips,
  Itinerary, Map, Gallery), and honest placeholder UX (the Gallery's "AI
  Video" stub explicitly says "nothing is generated yet" instead of faking
  it).
- Both `android/` and `ios/` platform folders are present and configured —
  this is not Android-only.

---

## Test & platform snapshot

- `flutter analyze`: **clean**.
- `flutter test`: **112/112 passing** (was 94/103 — see Blocker #1, now
  fixed).
- Test coverage is broad: stores, repositories, the offline cache, and most
  screens have dedicated tests (`test/` mirrors `lib/features/*` closely).
- `android/` and `ios/` both configured.
