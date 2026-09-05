import 'package:base_project/data/sample_trips.dart';
import 'package:base_project/data/trip.dart';
import 'package:base_project/dependency/dependency_manager.dart';
import 'package:base_project/features/planner/planner_screen.dart';
import 'package:base_project/features/planner/planner_store.dart';
import 'package:base_project/features/planner/trip_agent_transport.dart';
import 'package:base_project/features/trips/trips_store.dart';
import 'package:base_project/theme/kalsada_theme.dart';
import 'package:base_project/theme/theme_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_repository.dart';
import '../../support/finders.dart';

void main() {
  late FakeRepository<Trip> repository;

  setUp(() async {
    await sl.reset();
    repository = FakeRepository<Trip>();
    sl.registerSingleton(ThemeStore());
    sl.registerSingleton(TripsStore(tripsRepository: repository, authStore: null));
    sl.registerSingleton(PlannerStore(tripsRepository: repository, authStore: null));
    sl.registerFactory<TripAgentTransport>(
      () => SimulatedTripAgentTransport(
        generateTrip: (_) => SampleTrips.palawan(id: ''),
      ),
    );
  });

  tearDown(() async {
    repository.close();
    await sl.reset();
  });

  Widget app() => MaterialApp(
    theme: kalsadaTheme(Brightness.light),
    home: const PlannerScreen(),
  );

  testWidgets('idle state shows the suggestion prompts', (tester) async {
    await tester.pumpWidget(app());

    expect(find.text('Plan a Trip'), findsOneWidget);
    expect(
      find.text('Tell me about your trip, or try an idea below.'),
      findsOneWidget,
    );
    expect(find.text('6-day Palawan group ride, 6 riders'), findsOneWidget);
    expect(find.text('Weekend Cebu food trip for two'), findsOneWidget);
    expect(find.text('Solo Banaue rice terraces trek'), findsOneWidget);
    // The options pill shows the current defaults.
    expect(find.text('Motorcycle · 2 riders · Balanced'), findsOneWidget);
  });

  testWidgets('tapping a suggestion shows the user bubble and generates',
      (tester) async {
    // Tall viewport so the whole conversation feed mounts without scrolling.
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());

    await tester.tap(find.text('6-day Palawan group ride, 6 riders'));
    await tester.pump();

    // The prompt is echoed as a chat bubble while generation runs.
    expect(find.text('6-day Palawan group ride, 6 riders'), findsOneWidget);
    expect(sl<PlannerStore>().isGenerating, isTrue);

    // Let the staged generation (4 cards + closing text) play out.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(sl<PlannerStore>().isComplete, isTrue);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(findLabel('View Full Itinerary'), findsOneWidget);
    expect(find.text('Plan another trip'), findsOneWidget);
    // Generated GenUI cards are on screen.
    expect(find.text('GENERATED · OVERVIEW'), findsOneWidget);
    expect(find.text('GENERATED · GEAR CHECKLIST'), findsOneWidget);

    // The generated trip was persisted.
    expect(await repository.getById('id_0'), isNotNull);
  });

  testWidgets('a persisted error shows a dismissible banner on the idle view',
      (tester) async {
    sl<PlannerStore>().failGeneration('The trip agent is unavailable.');
    await tester.pumpWidget(app());

    expect(find.text('The trip agent is unavailable.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('The trip agent is unavailable.'), findsNothing);
  });
}
