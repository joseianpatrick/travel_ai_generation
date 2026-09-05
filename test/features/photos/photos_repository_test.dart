import 'package:base_project/data/trip_photo.dart';
import 'package:base_project/features/photos/photos_repository.dart';
import 'package:flutter_test/flutter_test.dart';

TripPhoto _photo({String id = ''}) => TripPhoto(
  id: id,
  tripId: 't1',
  dayNumber: 1,
  stopIndex: 0,
  url: 'https://example.com/photo.jpg',
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('LocalPhotosRepository', () {
    test('watch emits current photos immediately on listen', () async {
      final repository = LocalPhotosRepository();
      await repository.create('p1', _photo(id: 'p1'));

      final first = await repository.watch().first;
      expect(first.single.id, 'p1');
    });

    test('supports multiple listeners without throwing', () async {
      final repository = LocalPhotosRepository();
      final a = repository.watch().listen((_) {});
      final b = repository.watch().listen((_) {});
      await a.cancel();
      await b.cancel();
    });

    test('set stores under the given id and emits', () async {
      final repository = LocalPhotosRepository();
      await repository.create('abc', _photo());

      final stored = await repository.getById('abc');
      expect(stored, isNotNull);
      expect(stored!.id, 'abc');
    });

    test('update merges field-level data', () async {
      final repository = LocalPhotosRepository();
      await repository.create('p1', _photo(id: 'p1'));
      await repository.update('p1', {'caption': 'Great view'});

      final updated = await repository.getById('p1');
      expect(updated!.caption, 'Great view');
      expect(updated.tripId, 't1');
    });

    test('delete removes the photo', () async {
      final repository = LocalPhotosRepository();
      await repository.create('p1', _photo(id: 'p1'));
      await repository.delete('p1');

      expect(await repository.getById('p1'), isNull);
    });

    test('newId never collides across rapid calls', () {
      final repository = LocalPhotosRepository();
      final ids = {for (var i = 0; i < 100; i++) repository.newId()};
      expect(ids, hasLength(100));
    });
  });
}
