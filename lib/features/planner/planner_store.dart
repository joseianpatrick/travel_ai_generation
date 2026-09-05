import 'package:kalsada/data/repository/repository.dart';
import 'package:kalsada/data/trip.dart';
import 'package:kalsada/features/auth/auth_store.dart';
import 'package:kalsada/features/planner/planner_options.dart';
import 'package:mobx/mobx.dart';

part 'planner_store.g.dart';

/// Lifecycle of one AI trip-generation exchange on the Plan tab.
enum PlannerPhase { idle, generating, complete }

class PlannerStore = _PlannerStoreBase with _$PlannerStore;

abstract class _PlannerStoreBase with Store {
  _PlannerStoreBase({required this.tripsRepository, required this.authStore}) {
    // A finished conversation belongs to the signed-in user; reset it when
    // they sign out so the next account starts the Plan tab fresh.
    final auth = authStore;
    if (auth != null) {
      _authReaction = reaction<AuthStatus>((_) => auth.status, (status) {
        if (status == AuthStatus.signedOut) reset();
      });
    }
  }

  final Repository<Trip> tripsRepository;
  final AuthStore? authStore;

  ReactionDisposer? _authReaction;

  @observable
  PlannerPhase phase = PlannerPhase.idle;

  @observable
  String prompt = '';

  @observable
  Trip generatedTrip = Trip.empty();

  /// Why the last generation failed; empty when the last run succeeded.
  @observable
  String errorMessage = '';

  /// User-picked constraints that steer the next generation.
  @observable
  PlannerOptions options = const PlannerOptions();

  @action
  void updateOptions(PlannerOptions next) => options = next;

  @computed
  bool get isIdle => phase == PlannerPhase.idle;

  @computed
  bool get isGenerating => phase == PlannerPhase.generating;

  @computed
  bool get isComplete => phase == PlannerPhase.complete;

  @action
  void startGeneration(String userPrompt) {
    prompt = userPrompt;
    generatedTrip = Trip.empty();
    errorMessage = '';
    phase = PlannerPhase.generating;
  }

  /// Abandons the current generation, keeping the message for the UI to show.
  @action
  void failGeneration(String message) {
    errorMessage = message;
    prompt = '';
    generatedTrip = Trip.empty();
    phase = PlannerPhase.idle;
  }

  /// Persists the trip produced by the agent so it shows up on Home.
  @action
  Future<void> completeGeneration(Trip trip) async {
    final id = trip.id.isEmpty ? tripsRepository.newId() : trip.id;
    final saved = trip.copyWith(id: id).withStableItineraryIds();
    generatedTrip = saved;
    phase = PlannerPhase.complete;
    await tripsRepository.create(id, saved);
  }

  @action
  void clearError() => errorMessage = '';

  @action
  void reset() {
    phase = PlannerPhase.idle;
    prompt = '';
    generatedTrip = Trip.empty();
    errorMessage = '';
  }

  void dispose() {
    _authReaction?.call();
  }
}
