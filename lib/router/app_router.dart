import 'package:base_project/dependency/dependency_manager.dart';
import 'package:base_project/features/auth/auth_store.dart';
import 'package:base_project/features/auth/sign_in_screen.dart';
import 'package:base_project/features/auth/sign_up_screen.dart';
import 'package:base_project/features/gallery/gallery_screen.dart';
import 'package:base_project/features/itinerary/itinerary_screen.dart';
import 'package:base_project/features/map/map_screen.dart';
import 'package:base_project/features/nearby_food/nearby_food_screen.dart';
import 'package:base_project/features/onboarding/onboarding_screen.dart';
import 'package:base_project/features/planner/planner_screen.dart';
import 'package:base_project/features/splash/splash_screen.dart';
import 'package:base_project/features/trips/trip_edit_screen.dart';
import 'package:base_project/features/trips/trips_screen.dart';
import 'package:base_project/shared/widgets/app_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:mobx/mobx.dart' as mobx;

/// Re-runs router redirects whenever the auth status changes.
class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier(AuthStore store) {
    _disposer = mobx.reaction<AuthStatus>(
      (_) => store.status,
      (_) => notifyListeners(),
    );
  }

  late final mobx.ReactionDisposer _disposer;

  @override
  void dispose() {
    _disposer();
    super.dispose();
  }
}

const Set<String> _publicPaths = {'/splash', '/', '/signin', '/signup'};

final GoRouter router = GoRouter(
  initialLocation: '/splash',
  refreshListenable: AuthRefreshNotifier(sl<AuthStore>()),
  redirect: (context, state) {
    final signedIn = sl<AuthStore>().isSignedIn;
    final onPublicPage = _publicPaths.contains(state.matchedLocation);
    if (signedIn && onPublicPage) return '/home';
    if (!signedIn && !onPublicPage) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/signin',
      name: 'signin',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const TripsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/plan',
              name: 'plan',
              builder: (context, state) => const PlannerScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/map',
              name: 'map',
              builder: (context, state) => const MapScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/nearby-food',
              name: 'nearby-food',
              builder: (context, state) => const NearbyFoodScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/trip/:id',
      name: 'itinerary',
      builder: (context, state) =>
          ItineraryScreen(tripId: state.pathParameters['id'] ?? ''),
      routes: [
        GoRoute(
          path: 'edit',
          name: 'trip-edit',
          builder: (context, state) =>
              TripEditScreen(tripId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: 'gallery',
          name: 'gallery',
          builder: (context, state) =>
              GalleryScreen(tripId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
  ],
);
