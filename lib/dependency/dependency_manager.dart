import 'package:base_project/data/local/app_database.dart';
import 'package:base_project/data/local/caching_photos_repository.dart';
import 'package:base_project/data/local/caching_repository.dart';
import 'package:base_project/data/local/caching_trips_repository.dart';
import 'package:base_project/data/local/connectivity_service.dart';
import 'package:base_project/data/local/offline_cache_coordinator.dart';
import 'package:base_project/data/repository/auth_repository.dart';
import 'package:base_project/data/repository/repository.dart';
import 'package:base_project/data/sample_trips.dart';
import 'package:base_project/data/supabase/supabase_config.dart';
import 'package:base_project/data/trip.dart';
import 'package:base_project/data/trip_photo.dart';
import 'package:base_project/features/auth/auth_repository_impl.dart';
import 'package:base_project/features/auth/auth_store.dart';
import 'package:base_project/features/photos/photo_upload_service.dart';
import 'package:base_project/features/photos/photos_repository.dart';
import 'package:base_project/features/photos/photos_store.dart';
import 'package:base_project/features/planner/gemini_trip_agent_transport.dart';
import 'package:base_project/features/planner/plan_trip_service.dart';
import 'package:base_project/features/planner/planner_store.dart';
import 'package:base_project/features/planner/trip_agent_transport.dart';
import 'package:base_project/features/trips/trip_edit_store.dart';
import 'package:base_project/features/trips/trips_repository.dart';
import 'package:base_project/features/trips/trips_store.dart';
import 'package:base_project/theme/theme_store.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:get_it/get_it.dart';

GetIt sl = GetIt.instance;

class DependencyManager {
  void init() {
    //
    setThemeStore();
    setAuthStore();
    setLocalDatabase();
    setConnectivityService();
    setPlanTripService();
    final tripsCache = setTripStores();
    setPlannerTransport();
    final photosCache = setPhotoStores();
    setTileProvider();
    setSignOutHandling(tripsCache: tripsCache, photosCache: photosCache);
  }

  void setLocalDatabase() {
    sl.registerSingleton(AppDatabase());
  }

  void setPlanTripService() {
    sl.registerSingleton(
      PlanTripService(connectivity: sl<ConnectivityService>()),
    );
  }

  void setThemeStore() {
    sl.registerSingleton(ThemeStore());
  }

  void setConnectivityService() {
    sl.registerSingleton(ConnectivityService());
  }

  void setAuthStore() {
    final AuthRepository authRepository = SupabaseConfig.isConfigured
        ? SupabaseAuthRepository()
        : LocalAuthRepository();
    sl.registerSingleton(AuthStore(authRepository: authRepository));
  }

  /// Builds the trips stores and, when Supabase is configured, wraps the
  /// remote repository with the offline cache. Returns the caching
  /// repository (or `null` in the dev-mode fallback) so [setSignOutHandling]
  /// can wire it into the [OfflineCacheCoordinator] without DependencyManager
  /// needing to hold onto it as instance state.
  CachingRepository<Trip>? setTripStores() {
    final Repository<Trip> baseTripsRepository = SupabaseConfig.isConfigured
        ? SupabaseTripsRepository()
        : LocalTripsRepository(seed: [SampleTrips.palawan()]);
    // Only wrap the Supabase-backed path with the offline cache — the
    // Local*Repository dev-mode fallback has no remote to sync with and
    // stays untouched.
    final Repository<Trip> tripsRepository = SupabaseConfig.isConfigured
        ? CachingTripsRepository(
            remote: baseTripsRepository,
            db: sl<AppDatabase>(),
            connectivity: sl<ConnectivityService>(),
            ownerId: () =>
                sl<AuthStore>().authRepository.currentUserId ?? 'anon',
          )
        : baseTripsRepository;
    CachingRepository<Trip>? cachingTripsRepository;
    if (tripsRepository is CachingRepository<Trip>) {
      tripsRepository.startAutoFlush();
      cachingTripsRepository = tripsRepository;
    }
    final authStore = sl<AuthStore>();
    sl.registerSingleton(
      TripsStore(tripsRepository: tripsRepository, authStore: authStore),
    );
    sl.registerSingleton(
      PlannerStore(tripsRepository: tripsRepository, authStore: authStore),
    );
    sl.registerSingleton(
      TripEditStore(
        tripsRepository: tripsRepository,
        planTripService: sl<PlanTripService>(),
      ),
    );
    return cachingTripsRepository;
  }

  /// Factory, not singleton: each PlannerScreen owns and disposes its own
  /// transport alongside its GenUI conversation.
  void setPlannerTransport() {
    sl.registerFactory<TripAgentTransport>(
      () => SupabaseConfig.isConfigured
          ? GeminiTripAgentTransport(service: sl<PlanTripService>())
          : SimulatedTripAgentTransport(
              generateTrip: (_) => SampleTrips.palawan(id: ''),
            ),
    );
  }

  /// See [setTripStores] — same shape, returns the photos caching repository
  /// (or `null`) for [setSignOutHandling] to wire up.
  CachingRepository<TripPhoto>? setPhotoStores() {
    final Repository<TripPhoto> basePhotosRepository =
        SupabaseConfig.isConfigured
        ? SupabasePhotosRepository()
        : LocalPhotosRepository();
    final Repository<TripPhoto> photosRepository = SupabaseConfig.isConfigured
        ? CachingPhotosRepository(
            remote: basePhotosRepository,
            db: sl<AppDatabase>(),
            connectivity: sl<ConnectivityService>(),
            ownerId: () =>
                sl<AuthStore>().authRepository.currentUserId ?? 'anon',
          )
        : basePhotosRepository;
    CachingRepository<TripPhoto>? cachingPhotosRepository;
    if (photosRepository is CachingRepository<TripPhoto>) {
      photosRepository.startAutoFlush();
      cachingPhotosRepository = photosRepository;
    }
    sl.registerSingleton(
      PhotosStore(
        photosRepository: photosRepository,
        uploadService: SupabaseConfig.isConfigured
            ? PhotoUploadService()
            : null,
        authStore: sl<AuthStore>(),
      ),
    );
    return cachingPhotosRepository;
  }

  /// Map tiles are always disk-cached in the running app — [HiveCacheStore]
  /// is registered in `main.dart` before [init] runs. Widgets ask for a
  /// [TileProvider] the same way they ask for any other dependency; tests
  /// register their own fake instead of the widget introspecting whether
  /// caching is wired up.
  void setTileProvider() {
    sl.registerFactory<TileProvider>(
      () => CachedTileProvider(
        store: sl<HiveCacheStore>(),
        maxStale: const Duration(days: 30),
      ),
    );
  }

  /// Wires the offline cache's per-owner wipe into the same sign-out event
  /// that already clears TripsStore/PhotosStore's in-memory state, so a
  /// shared device doesn't leave one account's cached data queryable after
  /// the next account signs in. The fan-out policy itself lives in
  /// [OfflineCacheCoordinator] — this method only composes it.
  void setSignOutHandling({
    required CachingRepository<Trip>? tripsCache,
    required CachingRepository<TripPhoto>? photosCache,
  }) {
    final coordinator = OfflineCacheCoordinator(
      tripsCache: tripsCache,
      photosCache: photosCache,
    );
    sl<AuthStore>().onSignedOut = coordinator.clearForSignedOutUser;
  }
}
