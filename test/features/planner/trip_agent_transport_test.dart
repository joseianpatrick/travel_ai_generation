import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:kalsada/data/sample_trips.dart';
import 'package:kalsada/features/planner/trip_agent_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

void main() {
  test('sendRequest streams one create per generated card, then text',
      () async {
    final transport = SimulatedTripAgentTransport(
      generateTrip: (_) => SampleTrips.palawan(id: ''),
      stepDelay: Duration.zero,
    );
    final messages = <core.A2uiMessage>[];
    final texts = <String>[];
    transport.incomingMessages.listen(messages.add);
    transport.incomingText.listen(texts.add);

    await transport.sendRequest(ChatMessage.user('Palawan ride'));
    await Future<void>.delayed(Duration.zero);

    final creates = messages.whereType<core.CreateSurfaceMessage>().toList();
    expect(
      creates.map((m) => m.surfaceId),
      tripAgentSurfaceIds,
    );
    expect(
      messages.whereType<core.UpdateComponentsMessage>(),
      hasLength(tripAgentSurfaceIds.length),
    );
    expect(texts.single, contains('Palawan Coastal Loop'));
    expect(transport.lastGeneratedTrip, isNotNull);

    transport.dispose();
  });

  test('clearSurfaces deletes every generated surface', () async {
    final transport = SimulatedTripAgentTransport(
      generateTrip: (_) => SampleTrips.palawan(id: ''),
      stepDelay: Duration.zero,
    );
    final deletes = <core.A2uiMessage>[];
    transport.incomingMessages.listen(deletes.add);

    transport.clearSurfaces();
    await Future<void>.delayed(Duration.zero);

    expect(
      deletes.whereType<core.DeleteSurfaceMessage>().map((m) => m.surfaceId),
      tripAgentSurfaceIds,
    );
    transport.dispose();
  });

  test('rendered components carry the trip content', () async {
    final transport = SimulatedTripAgentTransport(
      generateTrip: (_) => SampleTrips.palawan(id: ''),
      stepDelay: Duration.zero,
    );
    final updates = <core.UpdateComponentsMessage>[];
    transport.incomingMessages.listen((message) {
      if (message is core.UpdateComponentsMessage) updates.add(message);
    });

    await transport.sendRequest(ChatMessage.user('Palawan ride'));
    await Future<void>.delayed(Duration.zero);

    final overview = updates
        .firstWhere((m) => m.surfaceId == 'trip-overview')
        .components
        .single;
    expect(overview['component'], 'TripOverviewCard');
    expect(overview['name'], 'Palawan Coastal Loop');
    expect(overview['riders'], 6);

    final route =
        updates.firstWhere((m) => m.surfaceId == 'trip-route').components.single;
    expect(route['days'], hasLength(6));

    transport.dispose();
  });
}
