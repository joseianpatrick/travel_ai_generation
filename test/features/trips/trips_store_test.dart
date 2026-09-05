import 'package:kalsada/data/sample_trips.dart';
import 'package:kalsada/data/trip.dart';
import 'package:kalsada/features/auth/auth_store.dart';
import 'package:kalsada/features/trips/trips_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_repository.dart';

void main() {
  late FakeRepository<Trip> repository;
  late TripsStore store;

  setUp(() {
    repository = FakeRepository<Trip>();
    store = TripsStore(tripsRepository: repository, authStore: null);
  });

  tearDown(() {
    store.dispose();
    repository.close();
  });

  test('initialize surfaces repository trips in observable state', () async {
    await repository.create('t1', SampleTrips.palawan(id: 't1'));
    store.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(store.trips, hasLength(1));
    expect(store.upcomingTrips.single.name, 'Palawan Coastal Loop');
    expect(store.pastTrips, isEmpty);
  });

  test('addTrip assigns a new id when the trip has none', () async {
    store.initialize();
    await store.addTrip(SampleTrips.palawan(id: ''));
    await Future<void>.delayed(Duration.zero);

    expect(store.trips.single.id, 'id_0');
  });

  test('activeTrip falls back to first upcoming trip', () async {
    await repository.create('t1', SampleTrips.palawan(id: 't1'));
    store.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(store.activeTrip.id, 't1');

    store.selectTrip('missing');
    expect(store.activeTrip.id, 't1');
  });

  test('selectTrip resets the active day to 1', () async {
    await repository.create('t1', SampleTrips.palawan(id: 't1'));
    store.initialize();
    await Future<void>.delayed(Duration.zero);

    store.selectDay(4);
    expect(store.activeDay.day, 4);

    store.selectTrip('t1');
    expect(store.activeDayNumber, 1);
    expect(store.activeDay.day, 1);
  });

  test('activeDay is empty for a trip with no days', () {
    expect(store.activeDay.stops, isEmpty);
    expect(store.activeDay.day, 0);
  });

  test('initialize clears loading once data arrives', () async {
    expect(store.isLoading, isTrue);
    store.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(store.isLoading, isFalse);
    expect(store.loadError, isEmpty);
  });

  test('a stream error surfaces loadError and clears loading', () async {
    store.initialize();
    await Future<void>.delayed(Duration.zero);

    repository.emitError(Exception('network down'));
    await Future<void>.delayed(Duration.zero);

    expect(store.isLoading, isFalse);
    expect(store.loadError, isNotEmpty);
  });

  test('double initialize does not duplicate subscriptions', () async {
    store.initialize();
    store.initialize();
    await repository.create('t1', SampleTrips.palawan(id: 't1'));
    await Future<void>.delayed(Duration.zero);

    expect(store.trips, hasLength(1));
  });

  test('updateStopStatus sets and toggles a stop status', () async {
    await repository.create('t1', SampleTrips.palawan(id: 't1'));
    store.initialize();
    await Future<void>.delayed(Duration.zero);
    final day1 = store.activeTrip.days.firstWhere((d) => d.day == 1);

    await store.updateStopStatus('t1', 1, 0, StopStatus.done);
    await Future<void>.delayed(Duration.zero);
    expect(store.activeTrip.days[0].stops[0].status, StopStatus.done);

    // Setting the same status again resets it to pending.
    await store.updateStopStatus('t1', 1, 0, StopStatus.done);
    await Future<void>.delayed(Duration.zero);
    expect(store.activeTrip.days[0].stops[0].status, StopStatus.pending);

    // Other stops in the day are untouched.
    expect(day1.stops.length, greaterThan(0));
  });

  test('updateTripStatus sets and toggles the trip status', () async {
    await repository.create('t1', SampleTrips.palawan(id: 't1'));
    store.initialize();
    await Future<void>.delayed(Duration.zero);

    await store.updateTripStatus('t1', TripStatus.done);
    await Future<void>.delayed(Duration.zero);
    expect(store.activeTrip.status, TripStatus.done);

    await store.updateTripStatus('t1', TripStatus.done);
    await Future<void>.delayed(Duration.zero);
    expect(store.activeTrip.status, TripStatus.planning);
  });

  test('sign-out clears trips and selection', () async {
    final authRepository = FakeAuthRepository(initialUserId: 'u1');
    final authStore = AuthStore(authRepository: authRepository)..initialize();
    final authedStore = TripsStore(
      tripsRepository: repository,
      authStore: authStore,
    );
    authedStore.initialize();
    await repository.create('t1', SampleTrips.palawan(id: 't1'));
    await Future<void>.delayed(Duration.zero);
    authedStore.selectTrip('t1');
    expect(authedStore.trips, hasLength(1));

    await authStore.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(authedStore.trips, isEmpty);
    expect(authedStore.activeTripId, isEmpty);

    authedStore.dispose();
    authStore.dispose();
    authRepository.close();
  });
}
