import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:kalsada/data/sample_trips.dart';
import 'package:kalsada/features/planner/gemini_trip_agent_transport.dart';
import 'package:kalsada/features/planner/plan_trip_service.dart';
import 'package:kalsada/features/planner/planner_options.dart';
import 'package:kalsada/features/planner/trip_agent_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

void main() {
  test('parses the function response and streams the trip surfaces', () async {
    final bodies = <Map<String, dynamic>>[];
    final transport = GeminiTripAgentTransport(
      stepDelay: Duration.zero,
      service: PlanTripService(
        invoke: (body) async {
          bodies.add(body);
          return {
            'trip': SampleTrips.palawan(id: '').toMap(),
            'summary': 'All set for Palawan!',
          };
        },
      ),
    );
    final messages = <core.A2uiMessage>[];
    final texts = <String>[];
    transport.incomingMessages.listen(messages.add);
    transport.incomingText.listen(texts.add);

    await transport.sendRequest(ChatMessage.user('Palawan ride'));
    await Future<void>.delayed(Duration.zero);

    expect(bodies.single['prompt'], 'Palawan ride');
    expect(transport.lastGeneratedTrip?.name, 'Palawan Coastal Loop');
    expect(transport.lastGeneratedTrip?.days, hasLength(6));
    expect(
      messages.whereType<core.CreateSurfaceMessage>().map((m) => m.surfaceId),
      tripAgentSurfaceIds,
    );
    expect(texts.single, 'All set for Palawan!');

    transport.dispose();
  });

  test('forwards pendingOptions to the function body', () async {
    final bodies = <Map<String, dynamic>>[];
    final transport =
        GeminiTripAgentTransport(
            stepDelay: Duration.zero,
            service: PlanTripService(
              invoke: (body) async {
                bodies.add(body);
                return {
                  'trip': SampleTrips.palawan(id: '').toMap(),
                  'summary': 'ok',
                };
              },
            ),
          )
          ..pendingOptions = const PlannerOptions(
            travelMode: TravelMode.car,
            groupSize: 4,
            avoidExpressways: true,
          );

    await transport.sendRequest(ChatMessage.user('Ilocos loop'));
    await Future<void>.delayed(Duration.zero);

    final options = bodies.single['options'] as Map<String, dynamic>;
    expect(options['travelMode'], 'car');
    expect(options['groupSize'], 4);
    expect(options['avoidExpressways'], true);

    transport.dispose();
  });

  test('throws the invoker error and leaves no generated trip', () async {
    final transport = GeminiTripAgentTransport(
      stepDelay: Duration.zero,
      service: PlanTripService(
        invoke: (_) async =>
            throw const TripAgentException('Sign in to plan trips.'),
      ),
    );

    await expectLater(
      transport.sendRequest(ChatMessage.user('Palawan ride')),
      throwsA(isA<TripAgentException>()),
    );
    expect(transport.lastGeneratedTrip, isNull);

    transport.dispose();
  });

  test('rejects a response without a usable trip', () async {
    final transport = GeminiTripAgentTransport(
      stepDelay: Duration.zero,
      service: PlanTripService(
        invoke: (_) async => {
          'trip': <String, dynamic>{'name': 'No days'},
          'summary': 'broken',
        },
      ),
    );

    await expectLater(
      transport.sendRequest(ChatMessage.user('Palawan ride')),
      throwsA(isA<TripAgentException>()),
    );
    expect(transport.lastGeneratedTrip, isNull);

    transport.dispose();
  });
}
