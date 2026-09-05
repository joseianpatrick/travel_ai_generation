import 'package:kalsada/data/repository/repository.dart';
import 'package:kalsada/data/trip.dart';
import 'package:kalsada/features/planner/plan_trip_service.dart';
import 'package:kalsada/features/planner/trip_agent_transport.dart';
import 'package:mobx/mobx.dart';

part 'trip_edit_store.g.dart';

class TripEditStore = _TripEditStoreBase with _$TripEditStore;

/// Backs the trip edit screen and the AI-refine sheet: manual saves and
/// one-shot AI revisions, both persisted under the trip's existing id so the
/// change flows back through the trips stream.
abstract class _TripEditStoreBase with Store {
  _TripEditStoreBase({
    required this.tripsRepository,
    required this.planTripService,
  });

  final Repository<Trip> tripsRepository;
  final PlanTripService planTripService;

  /// True while a save or refine is in flight.
  @observable
  bool isBusy = false;

  /// Why the last operation failed; empty on success.
  @observable
  String errorMessage = '';

  /// Persists manual edits. Throws [TripAgentException]-style failures upward
  /// via [errorMessage]; returns true on success.
  @action
  Future<bool> saveTrip(Trip trip) async {
    errorMessage = '';
    isBusy = true;
    try {
      await tripsRepository.create(trip.id, trip);
      return true;
    } catch (error) {
      errorMessage = 'Could not save your changes. Please try again.';
      return false;
    } finally {
      isBusy = false;
    }
  }

  /// Asks the model to revise [base] per [instruction], saving the result in
  /// place. Returns true on success.
  @action
  Future<bool> refineTrip(Trip base, String instruction) async {
    errorMessage = '';
    isBusy = true;
    try {
      final result = await planTripService.planTrip(
        prompt: instruction,
        baseTrip: base,
      );
      final revised = _preserveItineraryState(base, result.trip);
      await tripsRepository.create(base.id, revised);
      return true;
    } on TripAgentException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Could not refine this trip. Please try again.';
      return false;
    } finally {
      isBusy = false;
    }
  }
}

Trip _preserveItineraryState(Trip base, Trip generated) {
  final original = base.withStableItineraryIds();
  final days = <ItineraryDay>[];

  for (final candidateDay in generated.days) {
    final originalDay = _matchingDay(original.days, candidateDay);
    final stops = <TripStop>[];
    for (final candidateStop in candidateDay.stops) {
      final originalStop = originalDay == null
          ? null
          : _matchingStop(originalDay.stops, candidateStop);
      stops.add(
        candidateStop.copyWith(
          id:
              originalStop?.id ??
              (candidateStop.id.isNotEmpty
                  ? candidateStop.id
                  : newItineraryEntityId('stop')),
          latitude: candidateStop.latitude ?? originalStop?.latitude,
          longitude: candidateStop.longitude ?? originalStop?.longitude,
          status: originalStop?.status ?? candidateStop.status,
        ),
      );
    }
    days.add(
      candidateDay.copyWith(
        id:
            originalDay?.id ??
            (candidateDay.id.isNotEmpty
                ? candidateDay.id
                : newItineraryEntityId('day')),
        stops: stops,
      ),
    );
  }

  return generated
      .copyWith(
        id: original.id,
        isPast: original.isPast,
        status: original.status,
        days: days,
      )
      .withStableItineraryIds();
}

ItineraryDay? _matchingDay(
  List<ItineraryDay> originals,
  ItineraryDay candidate,
) {
  if (candidate.id.isNotEmpty) {
    for (final day in originals) {
      if (day.id == candidate.id) return day;
    }
  }
  final title = candidate.title.trim().toLowerCase();
  final matches = originals
      .where((day) => day.title.trim().toLowerCase() == title)
      .toList();
  return matches.length == 1 ? matches.single : null;
}

TripStop? _matchingStop(List<TripStop> originals, TripStop candidate) {
  if (candidate.id.isNotEmpty) {
    for (final stop in originals) {
      if (stop.id == candidate.id) return stop;
    }
  }
  final place = candidate.place.trim().toLowerCase();
  final time = candidate.time.trim().toLowerCase();
  final matches = originals
      .where(
        (stop) =>
            stop.place.trim().toLowerCase() == place &&
            stop.time.trim().toLowerCase() == time,
      )
      .toList();
  return matches.length == 1 ? matches.single : null;
}
