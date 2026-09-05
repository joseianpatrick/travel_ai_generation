import 'package:kalsada/features/onboarding/onboarding_screen.dart';
import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/finders.dart';

void main() {
  Widget app() => MaterialApp(
    theme: kalsadaTheme(Brightness.light),
    home: const OnboardingScreen(),
  );

  testWidgets('first slide shows Next and Skip, no Get Started',
      (tester) async {
    await tester.pumpWidget(app());

    expect(find.text('Kalsada'), findsOneWidget);
    expect(findLabel('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(findLabel('Get Started'), findsNothing);
  });

  testWidgets('Next advances through all slides to the actions',
      (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(findLabel('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Describe it, get a plan'), findsOneWidget);

    await tester.tap(findLabel('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Routes, mapped out'), findsOneWidget);

    await tester.tap(findLabel('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Ride together, sorted'), findsOneWidget);
    expect(findLabel('Get Started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
    expect(findLabel('Next'), findsNothing);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('Skip jumps straight to the last slide', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Ride together, sorted'), findsOneWidget);
    expect(findLabel('Get Started'), findsOneWidget);
  });
}
