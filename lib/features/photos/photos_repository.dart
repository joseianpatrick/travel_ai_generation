import 'dart:async';
import 'dart:math';

import 'package:kalsada/data/repository/repository.dart';
import 'package:kalsada/data/supabase/supabase_config.dart';
import 'package:kalsada/data/trip_photo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _generatePhotoId() {
  final random = Random().nextInt(0xFFFFFF).toRadixString(16);
  return 'photo_${DateTime.now().millisecondsSinceEpoch}_$random';
}

/// In-memory [Repository] used while Supabase credentials are placeholders.
class LocalPhotosRepository implements Repository<TripPhoto> {
  final Map<String, TripPhoto> _photos = {};
  final StreamController<List<TripPhoto>> _controller =
      StreamController.broadcast();

  void _emit() => _controller.add(_photos.values.toList());

  @override
  Stream<List<TripPhoto>> watch() async* {
    yield _photos.values.toList();
    yield* _controller.stream;
  }

  @override
  Future<TripPhoto?> getById(String id) async => _photos[id];

  @override
  Future<void> create(String id, TripPhoto value) async {
    _photos[id] = value.copyWith(id: id);
    _emit();
  }

  @override
  Future<void> update(String id, Map<String, Object?> data) async {
    final existing = _photos[id];
    if (existing == null) return;
    _photos[id] = TripPhoto.fromMap({...existing.toMap(), ...data});
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _photos.remove(id);
    _emit();
  }

  @override
  String newId() => _generatePhotoId();
}

/// Supabase-backed [Repository] for trip photo metadata.
///
/// Rows live in [SupabaseConfig.photosTable] as `{id, data jsonb}`; the
/// actual image bytes live in [SupabaseConfig.photosBucket], with the private
/// object path persisted in `data` and signed only when displayed.
class SupabasePhotosRepository implements Repository<TripPhoto> {
  SupabasePhotosRepository({this.clientOverride});

  /// Client injected in tests; production resolves the global instance.
  final SupabaseClient? clientOverride;

  SupabaseClient get _supabase => clientOverride ?? Supabase.instance.client;

  @override
  Stream<List<TripPhoto>> watch() {
    return _supabase
        .from(SupabaseConfig.photosTable)
        .stream(primaryKey: ['id'])
        .map(
          (rows) => rows
              .map((row) => TripPhoto.fromMap(_dataOf(row)))
              .where((photo) => photo.id.isNotEmpty)
              .toList(),
        );
  }

  Map<String, dynamic> _dataOf(Map<String, dynamic> row) {
    final data = row['data'];
    if (data is Map<String, dynamic>) return data;
    return const {};
  }

  @override
  Future<TripPhoto?> getById(String id) async {
    final row = await _supabase
        .from(SupabaseConfig.photosTable)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return TripPhoto.fromMap(_dataOf(row));
  }

  @override
  Future<void> create(String id, TripPhoto value) async {
    await _supabase.from(SupabaseConfig.photosTable).upsert({
      'id': id,
      'data': value.copyWith(id: id).toMap(),
    });
  }

  @override
  Future<void> update(String id, Map<String, Object?> data) async {
    final existing = await getById(id);
    if (existing == null) return;
    await _supabase
        .from(SupabaseConfig.photosTable)
        .update({
          'data': {...existing.toMap(), ...data},
        })
        .eq('id', id);
  }

  @override
  Future<void> delete(String id) async {
    await _supabase.from(SupabaseConfig.photosTable).delete().eq('id', id);
  }

  @override
  String newId() => _generatePhotoId();
}
