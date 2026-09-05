import 'package:kalsada/data/sample_trips.dart';
import 'package:kalsada/features/planner/plan_trip_service.dart';
import 'package:kalsada/features/planner/planner_options.dart';
import 'package:kalsada/features/planner/trip_agent_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sends the prompt, options, and baseTrip', () async {
    Map<String, dynamic>? sent;
    final service = PlanTripService(
      invoke: (body) async {
        sent = body;
        return {
          'trip': SampleTrips.palawan(id: '').toMap(),
          'summary': 'ok',
        };
      },
    );

    final result = await service.planTrip(
      prompt: 'make it cheaper',
      options: const PlannerOptions(groupSize: 3),
      baseTrip: SampleTrips.palawan(id: 'base'),
    );

    expect(sent!['prompt'], 'make it cheaper');
    final options = sent!['options'] as Map<String, dynamic>;
    expect(options['groupSize'], 3);
    expect(options['baseTrip'], isA<Map<String, dynamic>>());
    expect(result.trip.name, 'Palawan Coastal Loop');
    expect(result.summary, 'ok');
  });

  test('omits the options key when there is nothing to steer', () async {
    Map<String, dynamic>? sent;
    final service = PlanTripService(
      invoke: (body) async {
        sent = body;
        return {'trip': SampleTrips.palawan(id: '').toMap()};
      },
    );

    await service.planTrip(prompt: 'Palawan');

    expect(sent!.containsKey('options'), isFalse);
  });

  test('throws when the trip is missing or incomplete', () async {
    final noTrip = PlanTripService(invoke: (_) async => {'summary': 'none'});
    await expectLater(
      noTrip.planTrip(prompt: 'x'),
      throwsA(isA<TripAgentException>()),
    );

    final incomplete = PlanTripService(
      invoke: (_) async => {
        'trip': <String, dynamic>{'name': 'No days'},
      },
    );
    await expectLater(
      incomplete.planTrip(prompt: 'x'),
      throwsA(isA<TripAgentException>()),
    );
  });
}
