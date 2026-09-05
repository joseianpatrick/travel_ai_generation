import 'dart:async';

import 'package:base_project/data/repository/repository.dart';
import 'package:base_project/data/trip.dart';
import 'package:base_project/features/auth/auth_store.dart';
import 'package:mobx/mobx.dart';

part 'trips_store.g.dart';

class TripsStore = _TripsStoreBase with _$TripsStore;

abstract class _TripsStoreBase with Store {
  _TripsStoreBase({required this.tripsRepository, required this.authStore}) {
    // Drop the previous user's data the moment they sign out so an account
    // switch on the same device never shows stale trips.
    final auth = authStore;
    if (auth != null) {
      _authReaction = reaction<AuthStatus>((_) => auth.status, (status) {
        if (status == AuthStatus.signedOut) clearForSignOut();
      });
    }
  }

  final Repository<Trip> tripsRepository;
  final AuthStore? authStore;

  ReactionDisposer? _authReaction;

  @observable
  ObservableList<Trip> trips = ObservableList();

  @observable
  String activeTripId = '';

  @observable
  int activeDayNumber = 1;

  @observable
  bool isLoading = true;

  @observable
  String loadError = '';

  StreamSubscription<List<Trip>>? _streamSubscription;

  @computed
  List<Trip> get upcomingTrips => trips.where((t) => !t.isPast).toList();

  @computed
  List<Trip> get pastTrips => trips.where((t) => t.isPast).toList();

  /// Exact lookup for route-backed screens. Unlike [activeTrip], this never
  /// substitutes another trip when a stale/deleted deep link is opened.
  Trip tripById(String id) =>
      trips.firstWhere((trip) => trip.id == id, orElse: Trip.empty);

  @computed
  Trip get activeTrip {
    for (final trip in trips) {
      if (trip.id == activeTripId) return trip;
    }
    return upcomingTrips.isNotEmpty ? upcomingTrips.first : Trip.empty();
  }

  @computed
  ItineraryDay get activeDay {
    final days = activeTrip.days;
    if (days.isEmpty) return ItineraryDay.empty();
    for (final day in days) {
      if (day.day == activeDayNumber) return day;
    }
    return days.first;
  }

  @action
  void initialize() {
    _streamSubscription?.cancel();
    isLoading = true;
    loadError = '';
    _streamSubscription = tripsRepository.watch().listen(
      (data) {
        runInAction(() {
          trips = data.asObservable();
          isLoading = false;
          loadError = '';
        });
      },
      onError: (Object error) {
        runInAction(() {
          isLoading = false;
          loadError =
              'Could not load trips. Check your connection and '
              'try again.';
        });
      },
    );
  }

  @action
  void selectTrip(String id) {
    activeTripId = id;
    activeDayNumber = 1;
  }

  @action
  void selectDay(int day) => activeDayNumber = day;

  @action
  Future<void> addTrip(Trip trip) async {
    final id = trip.id.isEmpty ? tripsRepository.newId() : trip.id;
    await tripsRepository.create(
      id,
      trip.copyWith(id: id).withStableItineraryIds(),
    );
  }

  /// Sets [dayNumber]/[stopIndex]'s status, or resets it to [StopStatus.pending]
  /// if it already matches — so tapping the same action twice undoes it.
  @action
  Future<void> updateStopStatus(
    String tripId,
    int dayNumber,
    int stopIndex,
    StopStatus status,
  ) async {
    final trip = activeTrip.id == tripId
        ? activeTrip
        : trips.firstWhere((t) => t.id == tripId, orElse: Trip.empty);
    if (trip.id.isEmpty) return;
    final dayIndex = trip.days.indexWhere((d) => d.day == dayNumber);
    if (dayIndex == -1) return;
    final day = trip.days[dayIndex];
    if (stopIndex < 0 || stopIndex >= day.stops.length) return;
    final stop = day.stops[stopIndex];
    final nextStatus = stop.status == status ? StopStatus.pending : status;
    final stops = [...day.stops];
    stops[stopIndex] = stop.copyWith(status: nextStatus);
    final days = [...trip.days];
    days[dayIndex] = day.copyWith(stops: stops);
    await tripsRepository.create(tripId, trip.copyWith(days: days));
  }

  /// Sets [tripId]'s overall status, or resets it to [TripStatus.planning]
  /// if it already matches.
  @action
  Future<void> updateTripStatus(String tripId, TripStatus status) async {
    final trip = trips.firstWhere((t) => t.id == tripId, orElse: Trip.empty);
    if (trip.id.isEmpty) return;
    final nextStatus = trip.status == status ? TripStatus.planning : status;
    await tripsRepository.create(tripId, trip.copyWith(status: nextStatus));
  }

  @action
  void clearForSignOut() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    trips = ObservableList();
    activeTripId = '';
    activeDayNumber = 1;
    isLoading = true;
    loadError = '';
  }

  void dispose() {
    _authReaction?.call();
    _streamSubscription?.cancel();
  }
}
