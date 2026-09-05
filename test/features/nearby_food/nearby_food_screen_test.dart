import 'package:base_project/data/sample_trips.dart';
import 'package:base_project/data/trip.dart';
import 'package:base_project/dependency/dependency_manager.dart';
import 'package:base_project/features/nearby_food/nearby_food_screen.dart';
import 'package:base_project/features/trips/trips_store.dart';
import 'package:base_project/theme/kalsada_theme.dart';
import 'package:base_project/theme/theme_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_repository.dart';

void main() {
  late FakeRepository<Trip> repository;

  setUp(() async {
    await sl.reset();
    repository = FakeRepository<Trip>();
    sl.registerSingleton(ThemeStore());
    sl.registerSingleton(
      TripsStore(tripsRepository: repository, authStore: null),
    );
  });

  tearDown(() async {
    sl<TripsStore>().dispose();
    repository.close();
    await sl.reset();
  });

  Widget app() => MaterialApp(
    theme: kalsadaTheme(Brightness.light),
    home: const NearbyFoodScreen(),
  );

  testWidgets('asks the user to open an itinerary when none is active', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Nearby food is coming soon'), findsOneWidget);
    expect(
      find.text(
        'Open an itinerary to set the day and location for restaurant discovery.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses the selected itinerary day as the placeholder context', (
    tester,
  ) async {
    await repository.create('t1', SampleTrips.palawan(id: 't1'));
    sl<TripsStore>().initialize();
    await tester.pump();
    sl<TripsStore>().selectTrip('t1');
    sl<TripsStore>().selectDay(3);

    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Restaurants around Day 3'), findsOneWidget);
    expect(
      find.text('Palawan Coastal Loop · San Vicente → El Nido'),
      findsOneWidget,
    );
    expect(find.text('Restaurant discovery is coming soon'), findsOneWidget);
    expect(find.text('Cuisine'), findsOneWidget);
    expect(find.text('AI summary'), findsOneWidget);
  });
}
