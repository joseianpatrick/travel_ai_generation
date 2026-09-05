import 'dart:async';

import 'package:kalsada/data/repository/repository.dart';
import 'package:kalsada/data/trip.dart';
import 'package:kalsada/data/trip_photo.dart';
import 'package:kalsada/features/auth/auth_store.dart';
import 'package:kalsada/features/photos/photo_upload_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobx/mobx.dart';

part 'photos_store.g.dart';

class PhotosStore = _PhotosStoreBase with _$PhotosStore;

abstract class _PhotosStoreBase with Store {
  _PhotosStoreBase({
    required this.photosRepository,
    required this.uploadService,
    required this.authStore,
  }) {
    // Drop the previous user's photos the moment they sign out so an
    // account switch on the same device never shows stale photos.
    final auth = authStore;
    if (auth != null) {
      _authReaction = reaction<AuthStatus>((_) => auth.status, (status) {
        if (status == AuthStatus.signedOut) clearForSignOut();
      });
    }
  }

  final Repository<TripPhoto> photosRepository;

  /// Null in local dev-fallback mode, where picked files are stored by their
  /// on-device path instead of being uploaded to Supabase Storage.
  final PhotoUploadService? uploadService;

  final AuthStore? authStore;

  ReactionDisposer? _authReaction;

  @observable
  ObservableList<TripPhoto> photos = ObservableList();

  @observable
  bool isLoading = true;

  @observable
  String loadError = '';

  @observable
  bool isUploading = false;

  final ObservableMap<String, String> _signedUrls = ObservableMap();

  StreamSubscription<List<TripPhoto>>? _streamSubscription;

  @action
  void initialize() {
    _streamSubscription?.cancel();
    isLoading = true;
    loadError = '';
    _streamSubscription = photosRepository.watch().listen(
      (data) {
        runInAction(() {
          photos = data.asObservable();
          isLoading = false;
          loadError = '';
        });
        unawaited(_refreshSignedUrls(data));
      },
      onError: (Object error) {
        runInAction(() {
          isLoading = false;
          loadError =
              'Could not load photos. Check your connection and '
              'try again.';
        });
      },
    );
  }

  /// All photos for [tripId], most recent first.
  List<TripPhoto> forTrip(String tripId) =>
      photos.where((p) => p.tripId == tripId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// A local path, legacy public URL, or refreshed signed URL suitable for
  /// display. Reading this inside an Observer tracks signed-URL refreshes.
  String displayUrl(TripPhoto photo) =>
      _signedUrls[photo.id] ?? (photo.storagePath.isEmpty ? photo.url : '');

  Future<void> _refreshSignedUrls(List<TripPhoto> data) async {
    final service = uploadService;
    if (service == null) return;
    for (final photo in data) {
      final path = photo.storagePath.isNotEmpty
          ? photo.storagePath
          : service.pathFromLegacyUrl(photo.url);
      if (path == null || path.isEmpty) continue;
      try {
        final signedUrl = await service.createSignedUrl(path);
        runInAction(() => _signedUrls[photo.id] = signedUrl);
      } catch (_) {
        // Metadata remains available and a later stream emission retries.
      }
    }
  }

  /// Photos for [tripId] grouped by day number, day keys sorted ascending.
  Map<int, List<TripPhoto>> groupedByDay(String tripId, {Trip? trip}) {
    final grouped = <int, List<TripPhoto>>{};
    for (final photo in forTrip(tripId)) {
      final currentDayNumber = trip == null || photo.dayId.isEmpty
          ? photo.dayNumber
          : trip.days
                .firstWhere(
                  (day) => day.id == photo.dayId,
                  orElse: ItineraryDay.empty,
                )
                .day;
      grouped
          .putIfAbsent(
            currentDayNumber == 0 ? photo.dayNumber : currentDayNumber,
            () => [],
          )
          .add(photo);
    }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  int countForStop(
    String tripId,
    int dayNumber,
    int stopIndex, {
    String dayId = '',
    String stopId = '',
  }) => photos
      .where(
        (photo) => _matchesStop(
          photo,
          tripId,
          dayNumber,
          stopIndex,
          dayId: dayId,
          stopId: stopId,
        ),
      )
      .length;

  /// Most recently added photo for a stop, or null if none exist yet.
  TripPhoto? latestForStop(
    String tripId,
    int dayNumber,
    int stopIndex, {
    String dayId = '',
    String stopId = '',
  }) {
    final matches =
        photos
            .where(
              (photo) => _matchesStop(
                photo,
                tripId,
                dayNumber,
                stopIndex,
                dayId: dayId,
                stopId: stopId,
              ),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches.isEmpty ? null : matches.first;
  }

  /// All photos for one stop, oldest first.
  List<TripPhoto> forStop(
    String tripId,
    int dayNumber,
    int stopIndex, {
    String dayId = '',
    String stopId = '',
  }) =>
      photos
          .where(
            (photo) => _matchesStop(
              photo,
              tripId,
              dayNumber,
              stopIndex,
              dayId: dayId,
              stopId: stopId,
            ),
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @action
  Future<bool> addPhoto({
    required XFile file,
    required String tripId,
    required int dayNumber,
    required int stopIndex,
    String dayId = '',
    String stopId = '',
  }) async {
    isUploading = true;
    final id = photosRepository.newId();
    var storagePath = '';
    var metadataCreated = false;
    try {
      storagePath = uploadService?.createPath(file, tripId: tripId) ?? '';
      await photosRepository.create(
        id,
        TripPhoto(
          id: id,
          tripId: tripId,
          dayNumber: dayNumber,
          stopIndex: stopIndex,
          dayId: dayId,
          stopId: stopId,
          url: uploadService == null ? file.path : '',
          storagePath: storagePath,
          createdAt: DateTime.now(),
        ),
      );
      metadataCreated = true;
      if (uploadService != null) {
        await uploadService!.uploadToPath(file, storagePath);
        final signedUrl = await uploadService!.createSignedUrl(storagePath);
        runInAction(() => _signedUrls[id] = signedUrl);
      }
      return true;
    } catch (_) {
      if (metadataCreated) {
        try {
          await photosRepository.delete(id);
        } catch (_) {
          // The caching repository retains this rollback in its outbox.
        }
      }
      if (uploadService != null && storagePath.isNotEmpty) {
        try {
          await uploadService!.deletePath(storagePath);
        } catch (_) {
          // The original failure is what the UI can act on. Storage cleanup
          // is best-effort because no photo metadata exists to retry from.
        }
      }
      return false;
    } finally {
      runInAction(() => isUploading = false);
    }
  }

  bool _matchesStop(
    TripPhoto photo,
    String tripId,
    int dayNumber,
    int stopIndex, {
    required String dayId,
    required String stopId,
  }) {
    if (photo.tripId != tripId) return false;
    if (stopId.isNotEmpty && photo.stopId.isNotEmpty) {
      return photo.stopId == stopId;
    }
    if (dayId.isNotEmpty && photo.dayId.isNotEmpty && photo.dayId != dayId) {
      return false;
    }
    return photo.dayNumber == dayNumber && photo.stopIndex == stopIndex;
  }

  @action
  Future<bool> deletePhoto(String id) async {
    final photo = photos.firstWhere((p) => p.id == id, orElse: TripPhoto.empty);
    try {
      if (uploadService != null && photo.storagePath.isNotEmpty) {
        await uploadService!.deletePath(photo.storagePath);
      } else if (uploadService != null && photo.url.startsWith('http')) {
        await uploadService!.deleteByUrl(photo.url);
      }
      await photosRepository.delete(id);
      runInAction(() => _signedUrls.remove(id));
      return true;
    } catch (_) {
      // Keep metadata when deletion fails so the user can retry. Removing it
      // anyway would permanently orphan the private storage object.
      return false;
    }
  }

  @action
  void clearForSignOut() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    photos = ObservableList();
    _signedUrls.clear();
    isLoading = true;
    loadError = '';
  }

  void dispose() {
    _authReaction?.call();
    _streamSubscription?.cancel();
  }
}
