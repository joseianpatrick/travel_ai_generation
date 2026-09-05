# Kalsada contributor guidance

Kalsada is a Flutter AI travel planner. Android is the supported platform.
Read the relevant feature document in `docs/` before changing a feature
(`docs/planner.md`, `docs/itinerary.md`, `docs/trips.md`, and so on).

## Commands

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs # after MobX, freezed, or Drift annotation changes
flutter test
dart analyze
flutter build apk --debug
dart run tool/verify_supabase.dart # checks the live project; requires its configuration
```

Run the smallest relevant test while iterating, then run `dart analyze` and
the appropriate broader test suite before handing work off. Do not edit
generated `*.g.dart` or `*.freezed.dart` files by hand.

## Architecture

Dependency direction is:

```
UI (screens/widgets) -> MobX store -> Repository contract <- repository implementation
                                              ^
                                           models
```

- Models in `lib/data/` are pure Freezed/data classes: no Flutter, store, or
  repository dependencies.
- Repository contracts live in `lib/data/repository/`. Implementations belong
  beside their feature or in `lib/data/local/` / `lib/data/supabase/`.
- Stores live in `lib/features/<feature>/`, depend on repository interfaces
  through constructor injection, and contain no `BuildContext`, navigation,
  snackbars, widget code, or `sl<T>()` lookups.
- Screens/widgets render store state and invoke store actions. They must not
  import concrete repositories. Register concrete dependencies only in
  `lib/dependency/dependency_manager.dart`; `main.dart` is the sole caller of
  its `init()` method.
- Reuse `Repository<T>` implementations rather than adding a competing state
  management or dependency-injection system. This project uses MobX and
  get_it, not Bloc, Riverpod, Provider, or injectable.
- New top-level routes belong in `lib/router/app_router.dart`. Use named
  `go_router` navigation (`context.goNamed`); do not introduce inline
  `MaterialPageRoute`s for top-level screens.

## MobX and lifecycle

- Mark observable mutations as `@action`. Mutations performed in stream,
  timer, or other deferred callbacks must use `runInAction`.
- Use `@computed` for derived state. Cancel stream subscriptions and reaction
  disposers in `dispose()`; cancel an existing subscription before a store is
  re-initialized.
- Repository streams that can be re-subscribed by app-lifetime stores must use
  broadcast controllers.
- Dispose widget controllers and focus nodes. Check `mounted` before using
  `context` after an async gap.

## UI conventions

- Follow `lib/theme/kalsada_theme.dart` and access colors/text styles through
  `Theme.of(context)`. Avoid hard-coded colors and ad-hoc text styles.
- Use Material 3, `google_fonts`, 4/8-point spacing, and 16px horizontal
  screen gutters unless the surrounding feature establishes a different
  convention.
- Keep `Observer` scopes small and ensure each observer reads an observable.
  Cover loading, empty, error, and content states for list-like screens.
- Prefer `CustomScrollView`/slivers for feature screens, `const` constructors,
  48px minimum tap targets, semantic labels/tooltips, and adaptive controls.
- Put a shared widget in `lib/shared/widgets/` only after a second consumer;
  otherwise keep it feature-local. Extract repeated subtrees or long builds
  into widget classes.

## Tests

- Put unit and widget tests under the matching `test/features/<feature>/`
  directory. Exercise store/repository public APIs, not generated code.
- Inject fakes through constructors and reset get_it registrations in widget
  test setup and teardown. Test changed store actions and computed values;
  include widget coverage for changed screen behavior.
- Do not depend on real time, network access, or test ordering. Cover stream
  re-initialization and disposal where relevant.

## Supabase and secrets

- The project Supabase MCP connection is declared in `.mcp.json`. Treat it as
  an authenticated external system: inspect before mutating and do not make
  migrations, deploy functions, or change remote settings unless requested.
- Never expose service-role/secret keys in Flutter client code. Tables exposed
  through the Data API require RLS and policies that enforce ownership.
- Before changing Supabase schema, auth, RLS, Edge Functions, or client APIs,
  verify the current Supabase documentation and use the repository's existing
  migration workflow. Verify any change with targeted tests or a safe query.

## Scope and hygiene

- Preserve unrelated working-tree changes. Do not delete or overwrite user
  work to make a task easier.
- Prefer small, focused changes that match existing patterns. Update feature
  documentation when behavior, architecture, or setup changes.
- For reviews, report findings by severity with `file:line`, impact, and a
  concrete fix; verify a suspected issue before reporting it.
