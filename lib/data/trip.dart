import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'trip.freezed.dart';

final Random _itineraryIdRandom = Random.secure();

/// Creates a client-side identity for a newly added itinerary entity.
String newItineraryEntityId(String kind) {
  final random = _itineraryIdRandom.nextInt(0x7fffffff).toRadixString(36);
  return '$kind-${DateTime.now().microsecondsSinceEpoch}-$random';
}

/// Progress marker for a single stop, set as the rider actually travels the
/// itinerary (not during planning/generation).
enum StopStatus { pending, done, skipped }

StopStatus _stopStatusFromMap(Map<String, dynamic> map) =>
    StopStatus.values.asNameMap()[map['status'] as String? ?? ''] ??
    StopStatus.pending;

/// A single timed stop within an itinerary day.
@freezed
abstract class TripStop with _$TripStop {
  factory TripStop({
    @Default('') String id,
    required String time,
    required String place,
    required String note,
    double? latitude,
    double? longitude,
    @Default(StopStatus.pending) StopStatus status,
  }) = _TripStop;

  TripStop._();

  factory TripStop.fromMap(Map<String, dynamic> map) => TripStop(
    id: map['id'] as String? ?? '',
    time: map['time'] as String? ?? '',
    place: map['place'] as String? ?? '',
    note: map['note'] as String? ?? '',
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    status: _stopStatusFromMap(map),
  );

  factory TripStop.empty() => TripStop(time: '', place: '', note: '');

  /// True once the stop has been grounded with real coordinates, so it can
  /// be plotted as its own marker (older trips predate this field).
  bool get hasCoordinates => latitude != null && longitude != null;

  Map<String, dynamic> toMap() => {
    'id': id,
    'time': time,
    'place': place,
    'note': note,
    'latitude': latitude,
    'longitude': longitude,
    'status': status.name,
  };
}

/// One day of the trip route, anchored to its overnight/main location.
@freezed
abstract class ItineraryDay with _$ItineraryDay {
  factory ItineraryDay({
    @Default('') String id,
    required int day,
    required String title,
    required String distance,
    required String duration,
    required double latitude,
    required double longitude,
    required List<TripStop> stops,
    @Default('') String stay,
    @Default('') String stayPrice,
  }) = _ItineraryDay;

  ItineraryDay._();

  factory ItineraryDay.fromMap(Map<String, dynamic> map) => ItineraryDay(
    id: map['id'] as String? ?? '',
    day: (map['day'] as num?)?.toInt() ?? 0,
    title: map['title'] as String? ?? '',
    distance: map['distance'] as String? ?? '',
    duration: map['duration'] as String? ?? '',
    latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
    stops: ((map['stops'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TripStop.fromMap)
        .toList(),
    stay: map['stay'] as String? ?? '',
    stayPrice: map['stayPrice'] as String? ?? '',
  );

  factory ItineraryDay.empty() => ItineraryDay(
    day: 0,
    title: '',
    distance: '',
    duration: '',
    latitude: 0,
    longitude: 0,
    stops: [],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'day': day,
    'title': title,
    'distance': distance,
    'duration': duration,
    'latitude': latitude,
    'longitude': longitude,
    'stops': stops.map((s) => s.toMap()).toList(),
    'stay': stay,
    'stayPrice': stayPrice,
  };
}

/// A per-rider cost line item.
@freezed
abstract class BudgetItem with _$BudgetItem {
  factory BudgetItem({required String label, required String amount}) =
      _BudgetItem;

  BudgetItem._();

  factory BudgetItem.fromMap(Map<String, dynamic> map) => BudgetItem(
    label: map['label'] as String? ?? '',
    amount: map['amount'] as String? ?? '',
  );

  factory BudgetItem.empty() => BudgetItem(label: '', amount: '');

  Map<String, dynamic> toMap() => {'label': label, 'amount': amount};
}

/// A rider in the group, shown as an initialed avatar.
@freezed
abstract class Rider with _$Rider {
  factory Rider({required String initials, required int colorValue}) = _Rider;

  Rider._();

  factory Rider.fromMap(Map<String, dynamic> map) => Rider(
    initials: map['initials'] as String? ?? '',
    colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF007AFF,
  );

  factory Rider.empty() => Rider(initials: '', colorValue: 0xFF007AFF);

  Map<String, dynamic> toMap() => {
    'initials': initials,
    'colorValue': colorValue,
  };
}

/// Overall progress marker for a trip, separate from [Trip.isPast] (which is
/// just a date-based upcoming/past split).
enum TripStatus { planning, done, skipped }

/// A planned group trip: route days, budget, gear, and riders.
@freezed
abstract class Trip with _$Trip {
  factory Trip({
    required String id,
    required String name,
    required String datesLabel,
    required int nights,
    required String distanceTotal,
    required String totalPerRider,
    required String totalGroup,
    required bool isPast,
    required List<ItineraryDay> days,
    required List<BudgetItem> budgetItems,
    required List<String> gearItems,
    required List<Rider> riders,
    @Default('') String destination,
    @Default('') String coverImageUrl,
    @Default(TripStatus.planning) TripStatus status,
  }) = _Trip;

  Trip._();

  factory Trip.fromMap(Map<String, dynamic> map) {
    final trip = Trip(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      datesLabel: map['datesLabel'] as String? ?? '',
      nights: (map['nights'] as num?)?.toInt() ?? 0,
      distanceTotal: map['distanceTotal'] as String? ?? '',
      totalPerRider: map['totalPerRider'] as String? ?? '',
      totalGroup: map['totalGroup'] as String? ?? '',
      isPast: map['isPast'] as bool? ?? false,
      destination: map['destination'] as String? ?? '',
      coverImageUrl: map['coverImageUrl'] as String? ?? '',
      status:
          TripStatus.values.asNameMap()[map['status'] as String? ?? ''] ??
          TripStatus.planning,
      days: ((map['days'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ItineraryDay.fromMap)
          .toList(),
      budgetItems: ((map['budgetItems'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BudgetItem.fromMap)
          .toList(),
      gearItems: ((map['gearItems'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      riders: ((map['riders'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Rider.fromMap)
          .toList(),
    );
    return trip.withStableItineraryIds();
  }

  factory Trip.empty() => Trip(
    id: '',
    name: '',
    datesLabel: '',
    nights: 0,
    distanceTotal: '',
    totalPerRider: '',
    totalGroup: '',
    isPast: false,
    days: [],
    budgetItems: [],
    gearItems: [],
    riders: [],
  );

  int get riderCount => riders.length;

  /// Adds deterministic identities to legacy days/stops that predate ids.
  /// Existing ids are never replaced, so photos can safely keep referring to
  /// the same logical stop after a day is renumbered or a stop is reordered.
  Trip withStableItineraryIds() {
    if (id.isEmpty) return this;
    final normalizedDays = <ItineraryDay>[];
    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final day = days[dayIndex];
      final dayId = day.id.isEmpty ? '$id:day:${day.day}:$dayIndex' : day.id;
      final normalizedStops = <TripStop>[];
      for (var stopIndex = 0; stopIndex < day.stops.length; stopIndex++) {
        final stop = day.stops[stopIndex];
        normalizedStops.add(
          stop.id.isEmpty ? stop.copyWith(id: '$dayId:stop:$stopIndex') : stop,
        );
      }
      normalizedDays.add(day.copyWith(id: dayId, stops: normalizedStops));
    }
    return copyWith(days: normalizedDays);
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'datesLabel': datesLabel,
    'nights': nights,
    'distanceTotal': distanceTotal,
    'totalPerRider': totalPerRider,
    'totalGroup': totalGroup,
    'isPast': isPast,
    'days': days.map((d) => d.toMap()).toList(),
    'budgetItems': budgetItems.map((b) => b.toMap()).toList(),
    'gearItems': gearItems,
    'riders': riders.map((r) => r.toMap()).toList(),
    'destination': destination,
    'coverImageUrl': coverImageUrl,
    'status': status.name,
  };
}
