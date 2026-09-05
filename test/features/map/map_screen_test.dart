import 'package:kalsada/data/trip.dart';
import 'package:kalsada/dependency/dependency_manager.dart';
import 'package:kalsada/features/map/map_screen.dart';
import 'package:kalsada/features/trips/trips_store.dart';
import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:kalsada/theme/theme_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_repository.dart';

Trip _tripWithStops() => Trip(
  id: 't1',
  name: 'Test Trip',
  datesLabel: 'Jan 1–2, 2026',
  nights: 1,
  distanceTotal: '10 km',
  totalPerRider: '₱1,000',
  totalGroup: '₱2,000',
  isPast: false,
  budgetItems: const [],
  gearItems: const [],
  riders: const [],
  days: [
    ItineraryDay(
      day: 2,
      title: 'Day One',
      distance: '10 km',
      duration: '1h',
      latitude: 10.0,
      longitude: 119.0,
      stops: [
        TripStop(
          time: '7:00 AM',
          place: 'Grounded Stop',
          note: 'Has coordinates',
          latitude: 10.01,
          longitude: 119.01,
        ),
        TripStop(
          time: '9:00 AM',
          place: 'Ungrounded Stop',
          note: 'No coordinates yet',
        ),
      ],
    ),
  ],
);

void main() {
  late FakeRepository<Trip> repository;

  setUp(() async {
    await sl.reset();
    repository = FakeRepository<Trip>();
    await repository.create('t1', _tripWithStops());
    sl.registerSingleton(ThemeStore());
    sl.registerFactory<TileProvider>(NetworkTileProvider.new);
    sl.registerSingleton(
      TripsStore(tripsRepository: repository, authStore: null),
    );
    sl<TripsStore>().initialize();
    sl<TripsStore>().selectTrip('t1');
  });

  tearDown(() async {
    sl<TripsStore>().dispose();
    repository.close();
    await sl.reset();
  });

  Widget app() => MaterialApp(
    theme: kalsadaTheme(Brightness.light),
    home: const MapScreen(),
  );

  testWidgets('renders a marker only for stops with coordinates', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // The grounded stop gets a numbered pin (stop index 0 -> "1").
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(find.text('Grounded Stop'), findsOneWidget);
    expect(find.text('Ungrounded Stop'), findsNothing);
  });
}
