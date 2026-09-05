import 'package:base_project/data/sample_trips.dart';
import 'package:base_project/data/trip.dart';
import 'package:base_project/features/trips/trips_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalTripsRepository', () {
    test('watch emits the seed immediately on listen', () async {
      final repository = LocalTripsRepository(
        seed: [SampleTrips.palawan(id: 't1')],
      );

      final first = await repository.watch().first;
      expect(first.single.id, 't1');
    });

    test('supports multiple listeners without throwing', () async {
      final repository = LocalTripsRepository();
      final a = repository.watch().listen((_) {});
      final b = repository.watch().listen((_) {});
      await a.cancel();
      await b.cancel();
    });

    test('set stores under the given id and emits', () async {
      final repository = LocalTripsRepository();
      await repository.create('abc', SampleTrips.palawan(id: ''));

      final stored = await repository.getById('abc');
      expect(stored, isNotNull);
      expect(stored!.id, 'abc');
    });

    test('update merges field-level data', () async {
      final repository = LocalTripsRepository(
        seed: [SampleTrips.palawan(id: 't1')],
      );
      await repository.update('t1', {'name': 'Renamed Loop'});

      final updated = await repository.getById('t1');
      expect(updated!.name, 'Renamed Loop');
      expect(updated.days, hasLength(6));
    });

    test('delete removes the trip', () async {
      final repository = LocalTripsRepository(
        seed: [SampleTrips.palawan(id: 't1')],
      );
      await repository.delete('t1');

      expect(await repository.getById('t1'), isNull);
    });

    test('newId never collides across rapid calls', () {
      final repository = LocalTripsRepository();
      final ids = {for (var i = 0; i < 100; i++) repository.newId()};
      expect(ids, hasLength(100));
    });
  });

  group('Trip model round-trip', () {
    test('toMap/fromMap preserves the full trip', () {
      final trip = SampleTrips.palawan(id: 't1');
      final restored = Trip.fromMap(trip.toMap());

      expect(restored, equals(trip.withStableItineraryIds()));
      expect(restored.days, hasLength(6));
      expect(restored.days.first.id, isNotEmpty);
      expect(restored.days.first.stops, hasLength(4));
      expect(restored.days.first.stops.first.id, isNotEmpty);
      expect(restored.budgetItems, hasLength(6));
      expect(restored.riders, hasLength(6));
    });

    test('fromMap tolerates missing fields', () {
      final trip = Trip.fromMap(const {'id': 'x'});
      expect(trip.id, 'x');
      expect(trip.days, isEmpty);
      expect(trip.isPast, isFalse);
    });
  });

  group('TripStop coordinates', () {
    test('hasCoordinates is false when lat/lng are absent', () {
      final stop = TripStop.fromMap(const {
        'time': '7:00 AM',
        'place': 'Rider meetup',
        'note': 'Bike check',
      });
      expect(stop.hasCoordinates, isFalse);
    });

    test('fromMap/toMap round-trips latitude/longitude', () {
      final stop = TripStop(
        time: '7:00 AM',
        place: 'Rider meetup',
        note: 'Bike check',
        latitude: 10.2,
        longitude: 118.7,
      );
      final restored = TripStop.fromMap(stop.toMap());

      expect(restored, equals(stop));
      expect(restored.hasCoordinates, isTrue);
    });
  });
}
