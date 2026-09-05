import 'dart:developer' as developer;

import 'package:kalsada/data/local/connectivity_service.dart';
import 'package:kalsada/data/trip.dart';
import 'package:kalsada/features/planner/planner_options.dart';
import 'package:kalsada/features/planner/trip_agent_transport.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Low-level seam over the edge-function call, so tests can bypass Supabase.
typedef PlanTripFunctionInvoker =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> body);

/// The parsed result of a `plan-trip` call.
class PlanTripResult {
  const PlanTripResult({required this.trip, required this.summary});

  final Trip trip;
  final String summary;
}

/// Single entry point for the `plan-trip` Supabase Edge Function, used by both
/// the generation transport and the AI-refine flow. Sends the prompt plus
/// optional [PlannerOptions] and, for refine, a `baseTrip` to revise.
class PlanTripService {
  PlanTripService({PlanTripFunctionInvoker? invoke, this.connectivity})
    : _invoke = invoke ?? _invokeFunction;

  final PlanTripFunctionInvoker _invoke;

  /// Optional so existing tests constructing [PlanTripService] directly
  /// don't need to supply one; when absent, no offline pre-check runs.
  final ConnectivityService? connectivity;

  static const String functionName = 'plan-trip';

  static Future<Map<String, dynamic>> _invokeFunction(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        functionName,
        body: body,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw const TripAgentException(
        'The trip agent returned an unexpected response.',
      );
    } on FunctionException catch (error) {
      developer.log(
        'plan-trip function error (HTTP ${error.status}): ${error.details}',
        name: 'PlanTripService',
        error: error,
      );
      final details = error.details;
      final message = details is Map && details['error'] is String
          ? details['error'] as String
          : 'The trip planner is unavailable right now. Please try again '
                'in a moment.';
      throw TripAgentException(message);
    }
  }

  /// Calls the function and returns the parsed trip + summary, throwing a
  /// [TripAgentException] with a user-safe message on any failure.
  Future<PlanTripResult> planTrip({
    required String prompt,
    PlannerOptions? options,
    Trip? baseTrip,
  }) async {
    if (connectivity != null && !(await connectivity!.isOnline)) {
      throw const TripAgentException(
        "You're offline. Connect to the internet to generate or refine a trip.",
      );
    }
    final optionsMap = <String, dynamic>{
      if (options != null) ...options.toMap(),
      if (baseTrip != null) 'baseTrip': baseTrip.toMap(),
    };
    final data = await _invoke({
      'prompt': prompt,
      if (optionsMap.isNotEmpty) 'options': optionsMap,
    });
    final tripMap = data['trip'];
    if (tripMap is! Map<String, dynamic>) {
      throw const TripAgentException('The trip agent returned no trip.');
    }
    final trip = Trip.fromMap(tripMap);
    if (trip.name.isEmpty || trip.days.isEmpty) {
      throw const TripAgentException(
        'The trip agent returned an incomplete trip. Please try again.',
      );
    }
    final summary =
        data['summary'] as String? ??
        'Your ${trip.name} is mapped out and ready for the group.';
    return PlanTripResult(trip: trip, summary: summary);
  }
}
