import 'package:base_project/data/sample_trips.dart';
import 'package:base_project/data/trip.dart';
import 'package:base_project/dependency/dependency_manager.dart';
import 'package:base_project/features/planner/plan_trip_service.dart';
import 'package:base_project/features/trips/trip_edit_screen.dart';
import 'package:base_project/features/trips/trip_edit_store.dart';
import 'package:base_project/features/trips/trips_store.dart';
import 'package:base_project/theme/kalsada_theme.dart';
import 'package:base_project/theme/theme_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fakes/fake_repository.dart';

void main() {
  late FakeRepository<Trip> repository;

  setUp(() async {
    await sl.reset();
    repository = FakeRepository<Trip>();
    await repository.create('t1', SampleTrips.palawan(id: 't1'));
    sl.registerSingleton(ThemeStore());
    final tripsStore = TripsStore(tripsRepository: repository, authStore: null);
    tripsStore.trips.add(SampleTrips.palawan(id: 't1'));
    sl.registerSingleton(tripsStore);
    sl.registerSingleton(
      TripEditStore(
        tripsRepository: repository,
        planTripService: PlanTripService(invoke: (_) async => {}),
      ),
    );
  });

  tearDown(() async {
    repository.close();
    await sl.reset();
  });

  GoRouter buildRouter() => GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(body: SizedBox()),
      ),
      GoRoute(
        path: '/edit',
        builder: (c, s) => const TripEditScreen(tripId: 't1'),
      ),
    ],
  );

  testWidgets('renders seeded fields and saves edits', (tester) async {
    tester.view.physicalSize = const Size(900, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = buildRouter();
    await tester.pumpWidget(
      MaterialApp.router(
        theme: kalsadaTheme(Brightness.light),
        routerConfig: router,
      ),
    );
    router.push('/edit');
    await tester.pumpAndSettle();

    // Seeded trip name is shown in its field.
    expect(find.text('Palawan Coastal Loop'), findsOneWidget);
    expect(find.text('Edit Trip'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Palawan Coastal Loop'),
      'Palawan Remix',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The edit persisted through the store.
    expect((await repository.getById('t1'))?.name, 'Palawan Remix');
  });

  testWidgets('edits a day destination and its stay', (tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = buildRouter();
    await tester.pumpWidget(
      MaterialApp.router(
        theme: kalsadaTheme(Brightness.light),
        routerConfig: router,
      ),
    );
    router.push('/edit');
    await tester.pumpAndSettle();

    // Day 1's destination and seeded stay are editable text fields.
    expect(find.text('Destinations'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Puerto Princesa → Port Barton'),
      'Puerto Princesa → Sabang',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Port Barton Beach Camp'),
      'Sheridan Beach Resort',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '₱1,500–2,500 / night'),
      '₱3,000–4,000 / night',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repository.getById('t1');
    expect(saved?.days.first.title, 'Puerto Princesa → Sabang');
    expect(saved?.days.first.stay, 'Sheridan Beach Resort');
    expect(saved?.days.first.stayPrice, '₱3,000–4,000 / night');
  });

  testWidgets('blocks saving with an empty trip name', (tester) async {
    tester.view.physicalSize = const Size(900, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = buildRouter();
    await tester.pumpWidget(
      MaterialApp.router(
        theme: kalsadaTheme(Brightness.light),
        routerConfig: router,
      ),
    );
    router.push('/edit');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Palawan Coastal Loop'),
      '   ',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Trip name is required.'), findsOneWidget);
    // Nothing was persisted, and the sheet/screen stayed open.
    expect((await repository.getById('t1'))?.name, 'Palawan Coastal Loop');
    expect(find.text('Edit Trip'), findsOneWidget);
  });

  testWidgets('manual save preserves stop identity, coordinates, and status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final original = SampleTrips.palawan(id: 't1').withStableItineraryIds();
    final firstDay = original.days.first;
    final firstStop = firstDay.stops.first.copyWith(
      latitude: 10.1,
      longitude: 120.2,
      status: StopStatus.done,
    );
    final progressed = original.copyWith(
      days: [
        firstDay.copyWith(stops: [firstStop, ...firstDay.stops.skip(1)]),
        ...original.days.skip(1),
      ],
    );
    sl<TripsStore>().trips[0] = progressed;
    await repository.create('t1', progressed);

    final router = buildRouter();
    await tester.pumpWidget(
      MaterialApp.router(
        theme: kalsadaTheme(Brightness.light),
        routerConfig: router,
      ),
    );
    router.push('/edit');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final savedStop = (await repository.getById('t1'))!.days.first.stops.first;
    expect(savedStop.id, firstStop.id);
    expect(savedStop.latitude, firstStop.latitude);
    expect(savedStop.longitude, firstStop.longitude);
    expect(savedStop.status, StopStatus.done);
  });
}
