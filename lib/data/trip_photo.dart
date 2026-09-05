import 'package:freezed_annotation/freezed_annotation.dart';

part 'trip_photo.freezed.dart';

/// A user-captured photo tagged to a stable itinerary day and stop.
///
/// [dayNumber] and [stopIndex] remain for legacy rows and gallery ordering;
/// new rows also persist [dayId]/[stopId], which survive renumbering and
/// reordering.
@freezed
abstract class TripPhoto with _$TripPhoto {
  factory TripPhoto({
    required String id,
    required String tripId,
    required int dayNumber,
    required int stopIndex,
    @Default('') String dayId,
    @Default('') String stopId,
    required String url,
    @Default('') String storagePath,
    @Default('') String caption,
    required DateTime createdAt,
  }) = _TripPhoto;

  TripPhoto._();

  factory TripPhoto.fromMap(Map<String, dynamic> map) => TripPhoto(
    id: map['id'] as String? ?? '',
    tripId: map['tripId'] as String? ?? '',
    dayNumber: (map['dayNumber'] as num?)?.toInt() ?? 0,
    stopIndex: (map['stopIndex'] as num?)?.toInt() ?? -1,
    dayId: map['dayId'] as String? ?? '',
    stopId: map['stopId'] as String? ?? '',
    url: map['url'] as String? ?? '',
    storagePath: map['storagePath'] as String? ?? '',
    caption: map['caption'] as String? ?? '',
    createdAt:
        DateTime.tryParse(map['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  factory TripPhoto.empty() => TripPhoto(
    id: '',
    tripId: '',
    dayNumber: 0,
    stopIndex: -1,
    url: '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'tripId': tripId,
    'dayNumber': dayNumber,
    'stopIndex': stopIndex,
    'dayId': dayId,
    'stopId': stopId,
    'url': url,
    'storagePath': storagePath,
    'caption': caption,
    'createdAt': createdAt.toIso8601String(),
  };
}
