import 'package:base_project/data/sample_trips.dart';
import 'package:base_project/data/trip.dart';
import 'package:base_project/features/planner/plan_trip_service.dart';
import 'package:base_project/features/planner/trip_agent_transport.dart';
import 'package:base_project/features/trips/trip_edit_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_repository.dart';

void main() {
  late FakeRepository<Trip> repository;

  setUp(() => repository = FakeRepository<Trip>());
  tearDown(() => repository.close());

  test('saveTrip persists the edited trip', () async {
    final store = TripEditStore(
      tripsRepository: repository,
      planTripService: PlanTripService(invoke: (_) async => {}),
    );
    final trip = SampleTrips.palawan(id: 't1').copyWith(name: 'Renamed Loop');

    final ok = await store.saveTrip(trip);

    expect(ok, isTrue);
    expect(store.isBusy, isFalse);
    expect((await repository.getById('t1'))?.name, 'Renamed Loop');
  });

  test('refineTrip saves the revised trip under the same id', () async {
    Map<String, dynamic>? sent;
    final service = PlanTripService(
      invoke: (body) async {
        sent = body;
        return {
          'trip': SampleTrips.palawan(
            id: 'ignored',
          ).copyWith(name: 'Cheaper Loop').toMap(),
          'summary': 'done',
        };
      },
    );
    final store = TripEditStore(
      tripsRepository: repository,
      planTripService: service,
    );

    final ok = await store.refineTrip(
      SampleTrips.palawan(id: 'trip-9'),
      'make it cheaper',
    );

    expect(ok, isTrue);
    expect(sent!['prompt'], 'make it cheaper');
    final saved = await repository.getById('trip-9');
    expect(saved?.id, 'trip-9');
    expect(saved?.name, 'Cheaper Loop');
  });

  test('refineTrip surfaces the agent error message', () async {
    final store = TripEditStore(
      tripsRepository: repository,
      planTripService: PlanTripService(
        invoke: (_) async =>
            throw const TripAgentException('Sign in to plan trips.'),
      ),
    );

    final ok = await store.refineTrip(SampleTrips.palawan(id: 't'), 'x');

    expect(ok, isFalse);
    expect(store.errorMessage, 'Sign in to plan trips.');
    expect(store.isBusy, isFalse);
  });

  test(
    'refineTrip preserves stable ids, progress, and omitted coordinates',
    () async {
      final base = SampleTrips.palawan(id: 'trip-9').withStableItineraryIds();
      final originalDay = base.days.first;
      final originalStop = originalDay.stops.first.copyWith(
        status: StopStatus.done,
      );
      final progressed = base.copyWith(
        days: [
          originalDay.copyWith(
            stops: [originalStop, ...originalDay.stops.skip(1)],
          ),
          ...base.days.skip(1),
        ],
      );
      final generated = progressed.copyWith(
        days: [
          originalDay.copyWith(
            id: '',
            stops: [
              originalStop.copyWith(
                id: '',
                latitude: null,
                longitude: null,
                status: StopStatus.pending,
              ),
              ...originalDay.stops.skip(1),
            ],
          ),
          ...progressed.days.skip(1),
        ],
      );
      final store = TripEditStore(
        tripsRepository: repository,
        planTripService: PlanTripService(
          invoke: (_) async => {'trip': generated.toMap(), 'summary': 'done'},
        ),
      );

      expect(await store.refineTrip(progressed, 'rename the trip'), isTrue);

      final saved = await repository.getById('trip-9');
      final savedStop = saved!.days.first.stops.first;
      expect(saved.days.first.id, originalDay.id);
      expect(savedStop.id, originalStop.id);
      expect(savedStop.status, StopStatus.done);
      expect(savedStop.latitude, originalStop.latitude);
      expect(savedStop.longitude, originalStop.longitude);
    },
  );
}
