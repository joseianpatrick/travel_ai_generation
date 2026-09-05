import 'package:base_project/data/trip_photo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TripPhoto model round-trip', () {
    test('toMap/fromMap preserves the full photo', () {
      final photo = TripPhoto(
        id: 'p1',
        tripId: 't1',
        dayNumber: 2,
        stopIndex: 1,
        dayId: 'day-2',
        stopId: 'stop-1',
        url: '',
        storagePath: 'u1/t1/p1.jpg',
        caption: 'Sunset at the pier',
        createdAt: DateTime.utc(2026, 1, 15, 9, 30),
      );
      final restored = TripPhoto.fromMap(photo.toMap());

      expect(restored, equals(photo));
    });

    test('fromMap tolerates missing fields', () {
      final photo = TripPhoto.fromMap(const {'id': 'x'});
      expect(photo.id, 'x');
      expect(photo.tripId, isEmpty);
      expect(photo.stopIndex, -1);
      expect(photo.dayId, isEmpty);
      expect(photo.stopId, isEmpty);
      expect(photo.storagePath, isEmpty);
      expect(photo.caption, isEmpty);
    });
  });
}
