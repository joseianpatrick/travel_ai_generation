import 'package:kalsada/data/sample_trips.dart';
import 'package:kalsada/data/trip.dart';
import 'package:kalsada/data/trip_photo.dart';
import 'package:kalsada/dependency/dependency_manager.dart';
import 'package:kalsada/features/itinerary/itinerary_screen.dart';
import 'package:kalsada/features/photos/photos_store.dart';
import 'package:kalsada/features/trips/trips_store.dart';
import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:kalsada/theme/theme_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_repository.dart';
import '../../support/finders.dart';

void main() {
  late FakeRepository<Trip> repository;
  late FakeRepository<TripPhoto> photosRepository;

  setUp(() async {
    await sl.reset();
    repository = FakeRepository<Trip>();
    photosRepository = FakeRepository<TripPhoto>();
    await repository.create('t1', SampleTrips.palawan(id: 't1'));
    sl.registerSingleton(ThemeStore());
    sl.registerSingleton(
      TripsStore(tripsRepository: repository, authStore: null),
    );
    sl.registerSingleton(
      PhotosStore(
        photosRepository: photosRepository,
        uploadService: null,
        authStore: null,
      ),
    );
  });

  tearDown(() async {
    sl<TripsStore>().dispose();
    sl<PhotosStore>().dispose();
    repository.close();
    photosRepository.close();
    await sl.reset();
  });

  Widget app() => MaterialApp(
    theme: kalsadaTheme(Brightness.light),
    home: const ItineraryScreen(tripId: 't1'),
  );

  testWidgets('renders day 1 timeline and switches days', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Palawan Coastal Loop'), findsOneWidget);
    expect(find.text('Puerto Princesa → Port Barton'), findsOneWidget);
    expect(find.text('Rider meetup & bike check'), findsOneWidget);
    // The day's accommodation and its estimated price are surfaced.
    expect(
      find.text('Staying at Port Barton Beach Camp · ₱1,500–2,500 / night'),
      findsOneWidget,
    );
    // "Book This Trip" was replaced by trip-level Done/Skip actions.
    expect(find.text('Book This Trip'), findsNothing);
    expect(findLabel('Mark Trip as Done'), findsOneWidget);
    expect(find.text('Skip Trip'), findsOneWidget);
    // A shortcut to the map is available from the trip view.
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.text('Find nearby food'), findsOneWidget);

    await tester.tap(find.text('Day 3'));
    await tester.pump();

    expect(find.text('San Vicente → El Nido'), findsOneWidget);
    expect(find.text('Roadside buko stop'), findsOneWidget);
  });

  testWidgets('marking a stop done shows a Done chip', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Done'), findsNothing);
    await tester.tap(find.byTooltip('Mark as done').first);
    await tester.pump();

    expect(find.text('Done'), findsOneWidget);

    // Tapping the same action again undoes it.
    await tester.tap(find.byTooltip('Mark as done').first);
    await tester.pump();
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('marking the trip done shows a status banner with undo', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.tap(findLabel('Mark Trip as Done'));
    await tester.pump();

    expect(find.text('Trip marked as done'), findsOneWidget);
    expect(findLabel('Mark Trip as Done'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(findLabel('Mark Trip as Done'), findsOneWidget);
  });

  testWidgets('a load error offers retry instead of a blank trip', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('Palawan Coastal Loop'), findsOneWidget);

    repository.emitError(Exception('network down'));
    await tester.pump();

    expect(find.text('Palawan Coastal Loop'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await repository.create('t1', SampleTrips.palawan(id: 't1'));
    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(find.text('Palawan Coastal Loop'), findsOneWidget);
  });

  testWidgets('a stale route never falls back to another trip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kalsadaTheme(Brightness.light),
        home: const ItineraryScreen(tripId: 'deleted-trip'),
      ),
    );
    await tester.pump();

    expect(find.text('This trip no longer exists.'), findsOneWidget);
    expect(find.text('Palawan Coastal Loop'), findsNothing);
    expect(find.text('Mark Trip as Done'), findsNothing);
  });
}
