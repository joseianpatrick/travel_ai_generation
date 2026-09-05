import 'package:base_project/data/sample_trips.dart';
import 'package:base_project/data/trip.dart';
import 'package:base_project/features/auth/auth_store.dart';
import 'package:base_project/features/planner/planner_options.dart';
import 'package:base_project/features/planner/planner_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_repository.dart';

void main() {
  late FakeRepository<Trip> repository;
  late PlannerStore store;

  setUp(() {
    repository = FakeRepository<Trip>();
    store = PlannerStore(tripsRepository: repository, authStore: null);
  });

  tearDown(() {
    repository.close();
  });

  test('starts idle', () {
    expect(store.isIdle, isTrue);
    expect(store.isGenerating, isFalse);
    expect(store.isComplete, isFalse);
  });

  test('startGeneration records the prompt and enters generating', () {
    store.startGeneration('Palawan ride');

    expect(store.prompt, 'Palawan ride');
    expect(store.isGenerating, isTrue);
  });

  test('completeGeneration persists the trip with a fresh id', () async {
    store.startGeneration('Palawan ride');
    await store.completeGeneration(SampleTrips.palawan(id: ''));

    expect(store.isComplete, isTrue);
    expect(store.generatedTrip.id, 'id_0');
    expect(await repository.getById('id_0'), isNotNull);
  });

  test('completeGeneration keeps an existing id', () async {
    await store.completeGeneration(SampleTrips.palawan(id: 'fixed'));

    expect(store.generatedTrip.id, 'fixed');
    expect(await repository.getById('fixed'), isNotNull);
  });

  test('failGeneration returns to idle and keeps the message', () {
    store.startGeneration('Palawan ride');
    store.failGeneration('The trip agent is unavailable.');

    expect(store.isIdle, isTrue);
    expect(store.errorMessage, 'The trip agent is unavailable.');

    store.startGeneration('Palawan ride again');
    expect(store.errorMessage, isEmpty);
  });

  test('defaults to motorcycle options and updateOptions replaces them', () {
    expect(store.options.travelMode, TravelMode.motorcycle);
    expect(store.options.groupSize, 2);

    store.updateOptions(
      const PlannerOptions(travelMode: TravelMode.car, groupSize: 5),
    );

    expect(store.options.travelMode, TravelMode.car);
    expect(store.options.groupSize, 5);
  });

  test('reset returns to idle and clears state', () async {
    store.startGeneration('Palawan ride');
    await store.completeGeneration(SampleTrips.palawan(id: ''));
    store.reset();

    expect(store.isIdle, isTrue);
    expect(store.prompt, isEmpty);
    expect(store.generatedTrip.id, isEmpty);
  });

  test('sign-out resets the planner', () async {
    final authRepository = FakeAuthRepository(initialUserId: 'u1');
    final authStore = AuthStore(authRepository: authRepository)..initialize();
    final authedStore = PlannerStore(
      tripsRepository: repository,
      authStore: authStore,
    );
    authedStore.startGeneration('Palawan ride');
    await authedStore.completeGeneration(SampleTrips.palawan(id: ''));
    expect(authedStore.isComplete, isTrue);

    await authStore.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(authedStore.isIdle, isTrue);
    expect(authedStore.generatedTrip.id, isEmpty);

    authedStore.dispose();
    authStore.dispose();
    authRepository.close();
  });
}
