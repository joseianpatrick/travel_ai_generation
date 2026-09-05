# Auth

Email/password authentication, backed by Supabase Auth when configured and a
local in-memory stand-in otherwise.

**Routes:** `/signin` (name `signin`), `/signup` (name `signup`) — both
public paths.

**Key files:**
- `lib/features/auth/auth_store.dart` — MobX `AuthStore` (session status,
  loading/error state, validation)
- `lib/features/auth/auth_repository_impl.dart` — `SupabaseAuthRepository`
  and `LocalAuthRepository`, both implementing
  `lib/data/repository/auth_repository.dart`'s `AuthRepository` interface
- `lib/features/auth/sign_in_screen.dart`, `sign_up_screen.dart`,
  `widgets/auth_widgets.dart` — the two screens and their shared form widgets

## Backend selection

`DependencyManager.setAuthStore()` (`lib/dependency/dependency_manager.dart`)
picks the repository at startup:

- `SupabaseConfig.isConfigured` → `SupabaseAuthRepository` (real
  `supabase_flutter` `GoTrueClient` calls)
- otherwise → `LocalAuthRepository` — **any well-formed email/password
  succeeds**, no real backend, no persistence across app restarts. Local-dev
  only; never used once real Supabase credentials are in
  `lib/data/supabase/supabase_config.dart`.

## Flow

- **Sign up**: `AuthStore.signUp()` validates locally (email format,
  password ≥ 6 chars), then calls the repository. Supabase has "Confirm
  email" ON by default, so a fresh sign-up returns no session — the store
  sets `awaitingConfirmation = true` and the UI should prompt the user to
  check their inbox before signing in. (Disable this in Supabase Dashboard →
  Auth → Sign In / Up for faster local testing.)
- **Sign in**: `AuthStore.signIn()` → `signInWithPassword`.
- **Sign out**: triggered from the Home header (see [trips.md](./trips.md));
  `AuthStore.signOut()` clears the Supabase session, which cascades through
  `watchUserId()` back into `AuthStatus.signedOut`. The same transition path
  performs outgoing-user cache cleanup for explicit, expired, and external
  sign-outs.
- **Forgot password**: `AuthStore.sendPasswordReset(email)` →
  `resetPasswordForEmail`, surfaces a non-error `infoMessage` on success.

## Session restore & route guarding

- `AuthStore.initialize()` (called once at app start) reads
  `authRepository.currentUserId` synchronously for the initial status, then
  subscribes to `watchUserId()` for live updates (covers session
  expiry/external sign-out).
- `lib/router/app_router.dart`'s `AuthRefreshNotifier` reacts to
  `AuthStore.status` changes and re-runs the router's `redirect`: signed-out
  users are bounced to `/`, signed-in users on a public path are bounced to
  `/home`. Every trip screen therefore implicitly requires sign-in.

Downstream stores (`TripsStore`, `PlannerStore`, `PhotosStore`) each hold a
reference to `AuthStore` and clear their own state on `signedOut` so an
account switch on the same device never leaks the previous user's trips or
photos — see [trips.md](./trips.md). `AuthStore.onSignedOut` additionally
wipes that user's *offline-cached* rows and outbox (set by
`DependencyManager.setSignOutHandling()`) — see
[Offline Support](./offline.md#sign-out).
