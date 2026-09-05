import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:base_project/data/trip.dart';
import 'package:base_project/features/planner/kalsada_catalog.dart';
import 'package:base_project/features/planner/planner_options.dart';
import 'package:genui/genui.dart';
import 'package:meta/meta.dart';

/// Surface ids emitted per generation, in display order.
const List<String> tripAgentSurfaceIds = [
  'trip-overview',
  'trip-route',
  'trip-budget',
  'trip-gear',
];

/// A recoverable failure while generating a trip (network, agent, parsing).
class TripAgentException implements Exception {
  const TripAgentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Base GenUI [Transport] for the trip-planning agent.
///
/// Owns the A2UI streams and knows how to present a [Trip] as the four
/// generated surfaces with a staged reveal. Subclasses only decide where the
/// trip comes from: [SimulatedTripAgentTransport] fabricates one locally,
/// The live implementation asks Gemini through a Supabase Edge Function.
abstract class TripAgentTransport implements Transport {
  TripAgentTransport({this.stepDelay = const Duration(milliseconds: 1000)});

  /// Pause between generated cards, mimicking model streaming.
  final Duration stepDelay;

  final StreamController<core.A2uiMessage> _messages =
      StreamController.broadcast();
  final StreamController<String> _text = StreamController.broadcast();

  bool _disposed = false;

  /// The trip produced by the most recent [sendRequest], null on failure.
  Trip? lastGeneratedTrip;

  /// Constraints for the next [sendRequest]; set by the screen before sending.
  /// The simulated transport ignores it.
  PlannerOptions? pendingOptions;

  @override
  Stream<core.A2uiMessage> get incomingMessages => _messages.stream;

  @override
  Stream<String> get incomingText => _text.stream;

  /// Streams the four trip surfaces with [stepDelay] pauses, then [summary].
  @protected
  Future<void> emitTripSurfaces(Trip trip, String summary) async {
    final surfaces = <String, List<Map<String, Object?>>>{
      'trip-overview': [
        {
          'id': 'root',
          'component': 'TripOverviewCard',
          'name': trip.name,
          'dates': trip.datesLabel,
          'riders': trip.riderCount,
          'nights': trip.nights,
          'distance': trip.distanceTotal,
        },
      ],
      'trip-route': [
        {
          'id': 'root',
          'component': 'RouteCard',
          'days': [
            for (final day in trip.days)
              {'day': day.day, 'title': day.title, 'distance': day.distance},
          ],
        },
      ],
      'trip-budget': [
        {
          'id': 'root',
          'component': 'BudgetCard',
          'totalPerRider': trip.totalPerRider,
          'totalGroup': trip.totalGroup,
          'riders': trip.riderCount,
          'items': [
            for (final item in trip.budgetItems)
              {'label': item.label, 'amount': item.amount},
          ],
        },
      ],
      'trip-gear': [
        {
          'id': 'root',
          'component': 'GearChecklistCard',
          'items': trip.gearItems,
        },
      ],
    };

    for (final entry in surfaces.entries) {
      await Future<void>.delayed(stepDelay);
      if (_disposed) return;
      _messages.add(
        core.UpdateComponentsMessage(
          surfaceId: entry.key,
          components: entry.value,
        ),
      );
      _messages.add(
        core.CreateSurfaceMessage(
          surfaceId: entry.key,
          catalogId: kalsadaCatalogId,
        ),
      );
    }

    await Future<void>.delayed(stepDelay);
    if (_disposed) return;
    _text.add(summary);
  }

  /// Removes all generated surfaces (used by "Plan another trip").
  void clearSurfaces() {
    if (_disposed) return;
    for (final surfaceId in tripAgentSurfaceIds) {
      _messages.add(core.DeleteSurfaceMessage(surfaceId: surfaceId));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _messages.close();
    _text.close();
  }
}

/// Plays the trip agent locally with a canned trip — used when Supabase is
/// not configured, and as the deterministic double in widget tests.
class SimulatedTripAgentTransport extends TripAgentTransport {
  SimulatedTripAgentTransport({required this.generateTrip, super.stepDelay});

  /// Produces the trip for a prompt.
  final Trip Function(String prompt) generateTrip;

  @override
  Future<void> sendRequest(ChatMessage message) async {
    final trip = generateTrip(message.text);
    lastGeneratedTrip = trip;
    await emitTripSurfaces(
      trip,
      'Your ${trip.name} is mapped out — ${trip.days.length} days, '
      '${trip.distanceTotal}, ready for the group.',
    );
  }
}
