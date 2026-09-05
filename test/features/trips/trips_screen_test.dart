import 'package:kalsada/data/sample_trips.dart';
import 'package:kalsada/data/trip.dart';
import 'package:kalsada/dependency/dependency_manager.dart';
import 'package:kalsada/features/auth/auth_store.dart';
import 'package:kalsada/features/trips/trips_screen.dart';
import 'package:kalsada/features/trips/trips_store.dart';
import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:kalsada/theme/theme_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_repository.dart';

void main() {
  late FakeRepository<Trip> repository;

  setUp(() async {
    await sl.reset();
    repository = FakeRepository<Trip>();
    sl.registerSingleton(ThemeStore());
    sl.registerSingleton(
      AuthStore(authRepository: FakeAuthRepository(initialUserId: 'u1')),
    );
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
    home: const TripsScreen(),
  );

  testWidgets('shows empty states, then the added trip', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump();

    expect(
      find.text('No trips yet — plan one from the Plan tab.'),
      findsOneWidget,
    );
    expect(
      find.text('Your completed trips will show up here.'),
      findsOneWidget,
    );

    await repository.create('t1', SampleTrips.palawan(id: 't1'));
    await tester.pump();

    expect(find.text('Palawan Coastal Loop'), findsOneWidget);
    expect(find.text('Aug 14–19, 2026 · 5 nights'), findsOneWidget);
    expect(find.text('612 km'), findsOneWidget);
  });

  testWidgets('a done trip shows a Done badge on its card', (tester) async {
    await repository.create(
      't1',
      SampleTrips.palawan(id: 't1').copyWith(status: TripStatus.done),
    );
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump();

    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('past trips render under the Past section', (tester) async {
    await repository.create(
      't2',
      SampleTrips.palawan(id: 't2').copyWith(isPast: true),
    );
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump();

    expect(find.text('Palawan Coastal Loop'), findsOneWidget);
    expect(
      find.text('No trips yet — plan one from the Plan tab.'),
      findsOneWidget,
    );
  });
}
