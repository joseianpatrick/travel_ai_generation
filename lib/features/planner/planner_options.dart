import 'package:meta/meta.dart';

/// How the group travels — steers routes, distances, gear, and duration.
enum TravelMode {
  motorcycle('motorcycle', 'Motorcycle'),
  car('car', 'Car');

  const TravelMode(this.wire, this.label);

  /// Value sent to the edge function / model.
  final String wire;

  /// Human label shown in the options UI.
  final String label;
}

/// How densely the days are packed.
enum TripPace {
  chill('chill', 'Chill'),
  balanced('balanced', 'Balanced'),
  packed('packed', 'Packed');

  const TripPace(this.wire, this.label);

  final String wire;
  final String label;
}

/// Price tier for overnight stays — steers the hotels/lodging the model picks
/// and the `stayPrice` ranges it estimates.
enum LodgingBudget {
  budget('budget', 'Budget'),
  mid('mid', 'Mid-range'),
  premium('premium', 'Premium');

  const LodgingBudget(this.wire, this.label);

  final String wire;
  final String label;
}

/// Structured constraints the user picks before generating, sent to the
/// `plan-trip` function so the model can tailor (and the user can visualize)
/// the plan. Pure Dart so it is safe to hold in [PlannerStore].
@immutable
class PlannerOptions {
  const PlannerOptions({
    this.travelMode = TravelMode.motorcycle,
    this.avoidExpressways = false,
    this.groupSize = 2,
    this.pace = TripPace.balanced,
    this.lodgingBudget = LodgingBudget.mid,
    this.days,
  });

  final TravelMode travelMode;
  final bool avoidExpressways;
  final int groupSize;
  final TripPace pace;

  /// Price tier the model targets for overnight stays.
  final LodgingBudget lodgingBudget;

  /// Rough trip length in days; null lets the model choose.
  final int? days;

  PlannerOptions copyWith({
    TravelMode? travelMode,
    bool? avoidExpressways,
    int? groupSize,
    TripPace? pace,
    LodgingBudget? lodgingBudget,
    int? days,
    bool clearDays = false,
  }) {
    return PlannerOptions(
      travelMode: travelMode ?? this.travelMode,
      avoidExpressways: avoidExpressways ?? this.avoidExpressways,
      groupSize: groupSize ?? this.groupSize,
      pace: pace ?? this.pace,
      lodgingBudget: lodgingBudget ?? this.lodgingBudget,
      days: clearDays ? null : (days ?? this.days),
    );
  }

  /// Request-body shape consumed by the edge function.
  Map<String, dynamic> toMap() => {
    'travelMode': travelMode.wire,
    'avoidExpressways': avoidExpressways,
    'groupSize': groupSize,
    'pace': pace.wire,
    'lodgingBudget': lodgingBudget.wire,
    if (days != null) 'days': days,
  };

  /// Compact one-line summary for the options pill.
  String get summaryLabel {
    final parts = <String>[
      travelMode.label,
      '$groupSize ${groupSize == 1 ? 'rider' : 'riders'}',
      pace.label,
      if (avoidExpressways) 'No expressways',
      if (lodgingBudget != LodgingBudget.mid) '${lodgingBudget.label} stays',
      if (days != null) '$days ${days == 1 ? 'day' : 'days'}',
    ];
    return parts.join(' · ');
  }

  @override
  bool operator ==(Object other) =>
      other is PlannerOptions &&
      other.travelMode == travelMode &&
      other.avoidExpressways == avoidExpressways &&
      other.groupSize == groupSize &&
      other.pace == pace &&
      other.lodgingBudget == lodgingBudget &&
      other.days == days;

  @override
  int get hashCode => Object.hash(
    travelMode,
    avoidExpressways,
    groupSize,
    pace,
    lodgingBudget,
    days,
  );
}
