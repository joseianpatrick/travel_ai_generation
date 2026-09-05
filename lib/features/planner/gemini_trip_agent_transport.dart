import 'package:base_project/features/planner/plan_trip_service.dart';
import 'package:base_project/features/planner/trip_agent_transport.dart';
import 'package:genui/genui.dart';

/// The trip agent backed by Gemini via the `plan-trip` Supabase Edge Function.
class GeminiTripAgentTransport extends TripAgentTransport {
  GeminiTripAgentTransport({
    PlanTripService? service,
    super.stepDelay = const Duration(milliseconds: 350),
  }) : _service = service ?? PlanTripService();

  final PlanTripService _service;

  @override
  Future<void> sendRequest(ChatMessage message) async {
    lastGeneratedTrip = null;
    final result = await _service.planTrip(
      prompt: message.text,
      options: pendingOptions,
    );
    lastGeneratedTrip = result.trip;
    await emitTripSurfaces(result.trip, result.summary);
  }
}
