import 'package:base_project/features/planner/planner_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults produce a motorcycle, 2-rider, balanced plan', () {
    const options = PlannerOptions();

    expect(options.travelMode, TravelMode.motorcycle);
    expect(options.avoidExpressways, isFalse);
    expect(options.groupSize, 2);
    expect(options.pace, TripPace.balanced);
    expect(options.lodgingBudget, LodgingBudget.mid);
    expect(options.days, isNull);
    expect(options.summaryLabel, 'Motorcycle · 2 riders · Balanced');
  });

  test('toMap uses wire values and omits days when null', () {
    const options = PlannerOptions(
      travelMode: TravelMode.car,
      avoidExpressways: true,
      groupSize: 4,
      pace: TripPace.packed,
      lodgingBudget: LodgingBudget.premium,
    );

    expect(options.toMap(), {
      'travelMode': 'car',
      'avoidExpressways': true,
      'groupSize': 4,
      'pace': 'packed',
      'lodgingBudget': 'premium',
    });
  });

  test('summaryLabel shows lodging tier only when not the mid default', () {
    expect(
      const PlannerOptions(lodgingBudget: LodgingBudget.mid).summaryLabel,
      'Motorcycle · 2 riders · Balanced',
    );
    expect(
      const PlannerOptions(lodgingBudget: LodgingBudget.budget).summaryLabel,
      'Motorcycle · 2 riders · Balanced · Budget stays',
    );
  });

  test('toMap includes days when set', () {
    const options = PlannerOptions(days: 5);
    expect(options.toMap()['days'], 5);
  });

  test('summaryLabel reflects expressway and length choices', () {
    const options = PlannerOptions(
      groupSize: 1,
      avoidExpressways: true,
      days: 1,
    );
    expect(
      options.summaryLabel,
      'Motorcycle · 1 rider · Balanced · No expressways · 1 day',
    );
  });

  test('copyWith can clear days', () {
    const options = PlannerOptions(days: 3);
    expect(options.copyWith(clearDays: true).days, isNull);
    expect(options.copyWith(days: 4).days, 4);
  });

  test('value equality holds for identical options', () {
    expect(
      const PlannerOptions(travelMode: TravelMode.car),
      const PlannerOptions(travelMode: TravelMode.car),
    );
    expect(
      const PlannerOptions(groupSize: 2) == const PlannerOptions(groupSize: 3),
      isFalse,
    );
  });
}
