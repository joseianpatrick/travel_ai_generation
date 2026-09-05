# Onboarding

Four-slide intro carousel shown to signed-out users before they commit to
signing up.

**Route:** `/` (name `onboarding`) — the router's landing page and one of the
three public paths (alongside `/signin` and `/signup`) that
`AuthRefreshNotifier`'s redirect logic never gates behind sign-in.

**Key file:** `lib/features/onboarding/onboarding_screen.dart`

## How it works

- `_OnboardingScreenState` holds a single `_step` index into a hardcoded
  `_slides` list (name, body copy, and a pair of stripe colors per slide).
- Each slide renders a `TripPhotoBanner` in placeholder mode (striped
  gradient + caption, e.g. `"AI ITINERARY · PHOTO"`) — these are marketing
  slides with no real trip data behind them, so there's nothing to fetch a
  photo for.
- `Skip` (top-right, hidden on the last slide) jumps straight to the final
  slide. `Next` advances by one.
- The last slide swaps the "Next" button for two actions: **Get Started**
  (`context.goNamed('signup')`) and **I already have an account**
  (`context.goNamed('signin')`).

## Notes

- Purely presentational — no store, no persisted state. Re-entering this
  screen (e.g. after sign-out) always restarts at slide 0.
- See [auth.md](./auth.md) for what happens after "Get Started"/"I already
  have an account".
