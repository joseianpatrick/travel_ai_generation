import 'package:kalsada/features/planner/planner_options.dart';
import 'package:kalsada/features/planner/widgets/trip_options_sheet.dart';
import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<PlannerOptions?> openSheet(
    WidgetTester tester, {
    PlannerOptions initial = const PlannerOptions(),
  }) async {
    PlannerOptions? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: kalsadaTheme(Brightness.light),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showTripOptionsSheet(context, initial);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('trip length stops incrementing at the max', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await openSheet(tester, initial: const PlannerOptions(days: 21));

    expect(find.text('21 days'), findsOneWidget);

    final incrementButtons = find.byIcon(Icons.add);
    // The last "+" on screen is the length stepper's (group size comes first).
    await tester.tap(incrementButtons.last);
    await tester.pump();

    expect(find.text('21 days'), findsOneWidget);
  });
}
