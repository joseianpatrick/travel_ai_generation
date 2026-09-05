import 'package:kalsada/dependency/dependency_manager.dart';
import 'package:kalsada/features/auth/auth_store.dart';
import 'package:kalsada/features/auth/sign_in_screen.dart';
import 'package:kalsada/features/auth/sign_up_screen.dart';
import 'package:kalsada/features/gallery/gallery_screen.dart';
import 'package:kalsada/features/itinerary/itinerary_screen.dart';
import 'package:kalsada/features/map/map_screen.dart';
import 'package:kalsada/features/nearby_food/nearby_food_screen.dart';
import 'package:kalsada/features/onboarding/onboarding_screen.dart';
import 'package:kalsada/features/planner/planner_screen.dart';
import 'package:kalsada/features/splash/splash_screen.dart';
import 'package:kalsada/features/trips/trip_edit_screen.dart';
import 'package:kalsada/features/trips/trips_screen.dart';
import 'package:kalsada/shared/widgets/app_shell.dart';
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
