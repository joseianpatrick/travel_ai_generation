import 'package:base_project/data/trip_photo.dart';
import 'package:base_project/data/trip.dart';
import 'package:base_project/features/auth/auth_store.dart';
import 'package:base_project/features/photos/photo_upload_service.dart';
import 'package:base_project/features/photos/photos_store.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_repository.dart';

class _FakePhotoUploadService extends PhotoUploadService {
  bool failDelete = false;

  @override
  Future<String> createSignedUrl(String path) async =>
      'https://signed.example/$path';

  @override
  Future<void> deletePath(String path) async {
    if (failDelete) throw Exception('storage unavailable');
  }
}

void main() {
  late FakeRepository<TripPhoto> repository;
  late PhotosStore store;

  setUp(() {
    repository = FakeRepository<TripPhoto>();
    store = PhotosStore(
      photosRepository: repository,
      uploadService: null,
      authStore: null,
    );
  });

  tearDown(() {
    store.dispose();
    repository.close();
  });

  test('initialize surfaces repository photos in observable state', () async {
    await repository.create(
      'p1',
      TripPhoto(
        id: 'p1',
        tripId: 't1',
        dayNumber: 1,
        stopIndex: 0,
        url: 'https://example.com/p1.jpg',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    store.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(store.photos, hasLength(1));
    expect(store.forTrip('t1'), hasLength(1));
    expect(store.forTrip('other'), isEmpty);
  });

  test('groupedByDay groups and sorts by day number', () async {
    await repository.create(
      'p1',
      TripPhoto(
        id: 'p1',
        tripId: 't1',
        dayNumber: 2,
        stopIndex: 0,
        url: 'https://example.com/p1.jpg',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await repository.create(
      'p2',
      TripPhoto(
        id: 'p2',
        tripId: 't1',
        dayNumber: 1,
        stopIndex: 0,
        url: 'https://example.com/p2.jpg',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );
    store.initialize();
    await Future<void>.delayed(Duration.zero);

    final grouped = store.groupedByDay('t1');
    expect(grouped.keys.toList(), [1, 2]);
    expect(grouped[1]!.single.id, 'p2');
    expect(grouped[2]!.single.id, 'p1');
  });

  test('countForStop and latestForStop scope by trip/day/stop', () async {
    await repository.create(
      'p1',
      TripPhoto(
        id: 'p1',
        tripId: 't1',
        dayNumber: 1,
        stopIndex: 0,
        url: 'https://example.com/p1.jpg',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await repository.create(
      'p2',
      TripPhoto(
        id: 'p2',
        tripId: 't1',
        dayNumber: 1,
        stopIndex: 0,
        url: 'https://example.com/p2.jpg',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );
    store.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(store.countForStop('t1', 1, 0), 2);
    expect(store.countForStop('t1', 1, 1), 0);
    expect(store.latestForStop('t1', 1, 0)!.id, 'p2');
  });

  test('forStop returns matching photos oldest first', () async {
    await repository.create(
      'p1',
      TripPhoto(
        id: 'p1',
        tripId: 't1',
        dayNumber: 1,
        stopIndex: 0,
        url: 'https://example.com/p1.jpg',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );
    await repository.create(
      'p2',
      TripPhoto(
        id: 'p2',
        tripId: 't1',
        dayNumber: 1,
        stopIndex: 0,
        url: 'https://example.com/p2.jpg',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    store.initialize();
    await Future<void>.delayed(Duration.zero);

    final stopPhotos = store.forStop('t1', 1, 0);
    expect(stopPhotos.map((p) => p.id).toList(), ['p2', 'p1']);
    expect(store.forStop('t1', 1, 1), isEmpty);
  });

  test('stable stop ids survive day renumbering and stop reordering', () async {
    await repository.create(
      'p1',
      TripPhoto(
        id: 'p1',
        tripId: 't1',
        dayNumber: 2,
        stopIndex: 1,
        dayId: 'day-b',
        stopId: 'stop-b',
        url: '/tmp/p1.jpg',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    store.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(
      store.forStop('t1', 1, 0, dayId: 'day-b', stopId: 'stop-b'),
      hasLength(1),
    );
    final trip = Trip.empty().copyWith(
      id: 't1',
      days: [ItineraryDay.empty().copyWith(id: 'day-b', day: 1)],
    );
    expect(store.groupedByDay('t1', trip: trip).keys, [1]);
  });

  test('addPhoto in local mode stores the file path as the url', () async {
    store.initialize();
    final ok = await store.addPhoto(
      file: XFile('/tmp/picked.jpg'),
      tripId: 't1',
      dayNumber: 1,
      stopIndex: 0,
    );
    await Future<void>.delayed(Duration.zero);

    expect(ok, isTrue);
    expect(store.forTrip('t1').single.url, '/tmp/picked.jpg');
    expect(store.isUploading, isFalse);
  });

  test('deletePhoto removes it from the repository', () async {
    await repository.create(
      'p1',
      TripPhoto(
        id: 'p1',
        tripId: 't1',
        dayNumber: 1,
        stopIndex: 0,
        url: 'https://example.com/p1.jpg',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    store.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(await store.deletePhoto('p1'), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(store.photos, isEmpty);
  });

  test('private and legacy paths are resolved to signed URLs', () async {
    final upload = _FakePhotoUploadService();
    final remoteStore = PhotosStore(
      photosRepository: repository,
      uploadService: upload,
      authStore: null,
    );
    addTearDown(remoteStore.dispose);
    await repository.create(
      'private',
      TripPhoto(
        id: 'private',
        tripId: 't1',
        dayNumber: 1,
        stopIndex: 0,
        url: '',
        storagePath: 'u1/t1/private.jpg',
        createdAt: DateTime.utc(2026),
      ),
    );
    await repository.create(
      'legacy',
      TripPhoto(
        id: 'legacy',
        tripId: 't1',
        dayNumber: 1,
        stopIndex: 0,
        url:
            'https://project.supabase.co/storage/v1/object/public/'
            'trip-photos/t1/legacy.jpg',
        createdAt: DateTime.utc(2026),
      ),
    );

    remoteStore.initialize();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      remoteStore.displayUrl(
        remoteStore.photos.firstWhere((p) => p.id == 'private'),
      ),
      'https://signed.example/u1/t1/private.jpg',
    );
    expect(
      remoteStore.displayUrl(
        remoteStore.photos.firstWhere((p) => p.id == 'legacy'),
      ),
      'https://signed.example/t1/legacy.jpg',
    );
  });

  test('failed storage deletion keeps metadata available for retry', () async {
    final upload = _FakePhotoUploadService()..failDelete = true;
    final remoteStore = PhotosStore(
      photosRepository: repository,
      uploadService: upload,
      authStore: null,
    );
    addTearDown(remoteStore.dispose);
    await repository.create(
      'p1',
      TripPhoto(
        id: 'p1',
        tripId: 't1',
        dayNumber: 1,
        stopIndex: 0,
        url: '',
        storagePath: 'u1/t1/p1.jpg',
        createdAt: DateTime.utc(2026),
      ),
    );
    remoteStore.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(await remoteStore.deletePhoto('p1'), isFalse);
    expect(await repository.getById('p1'), isNotNull);
  });

  test('sign-out clears photos', () async {
    final authRepository = FakeAuthRepository(initialUserId: 'u1');
    final authStore = AuthStore(authRepository: authRepository)..initialize();
    final authedStore = PhotosStore(
      photosRepository: repository,
      uploadService: null,
      authStore: authStore,
    );
    authedStore.initialize();
    await repository.create(
      'p1',
      TripPhoto(
        id: 'p1',
        tripId: 't1',
        dayNumber: 1,
        stopIndex: 0,
        url: 'https://example.com/p1.jpg',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(authedStore.photos, hasLength(1));

    await authStore.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(authedStore.photos, isEmpty);

    authedStore.dispose();
    authStore.dispose();
    authRepository.close();
  });
}
