import 'dart:async';
import 'dart:math';

import 'package:kalsada/data/repository/repository.dart';
import 'package:kalsada/data/supabase/supabase_config.dart';
import 'package:kalsada/data/trip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _generateTripId() {
  final random = Random().nextInt(0xFFFFFF).toRadixString(16);
  return 'trip_${DateTime.now().millisecondsSinceEpoch}_$random';
}

/// In-memory [Repository] used while Supabase credentials are placeholders.
///
/// Seeded with sample content so the app is fully browsable offline.
class LocalTripsRepository implements Repository<Trip> {
  LocalTripsRepository({List<Trip> seed = const []}) {
    for (final trip in seed) {
      _trips[trip.id] = trip.withStableItineraryIds();
    }
  }

  final Map<String, Trip> _trips = {};
  final StreamController<List<Trip>> _controller = StreamController.broadcast();

  void _emit() => _controller.add(_trips.values.toList());

  @override
  Stream<List<Trip>> watch() async* {
    yield _trips.values.toList();
    yield* _controller.stream;
  }

  @override
  Future<Trip?> getById(String id) async => _trips[id];

  @override
  Future<void> create(String id, Trip value) async {
    _trips[id] = value.copyWith(id: id).withStableItineraryIds();
    _emit();
  }

  @override
  Future<void> update(String id, Map<String, Object?> data) async {
    final existing = _trips[id];
    if (existing == null) return;
    _trips[id] = Trip.fromMap({...existing.toMap(), ...data});
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _trips.remove(id);
    _emit();
  }

  @override
  String newId() => _generateTripId();
}

/// Supabase-backed [Repository] for trips.
///
/// Rows live in [SupabaseConfig.tripsTable] as `{id, data jsonb}`; realtime
/// updates flow through [watch].
class SupabaseTripsRepository implements Repository<Trip> {
  SupabaseTripsRepository({this.clientOverride});

  /// Client injected in tests; production resolves the global instance.
  final SupabaseClient? clientOverride;

  SupabaseClient get _supabase => clientOverride ?? Supabase.instance.client;

  @override
  Stream<List<Trip>> watch() {
    return _supabase
        .from(SupabaseConfig.tripsTable)
        .stream(primaryKey: ['id'])
        .map(
          (rows) => rows
              .map((row) => Trip.fromMap(_dataOf(row)))
              .where((trip) => trip.id.isNotEmpty)
              .toList(),
        );
  }

  Map<String, dynamic> _dataOf(Map<String, dynamic> row) {
    final data = row['data'];
    if (data is Map<String, dynamic>) return data;
    return const {};
  }

  @override
  Future<Trip?> getById(String id) async {
    final row = await _supabase
        .from(SupabaseConfig.tripsTable)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Trip.fromMap(_dataOf(row));
  }

  @override
  Future<void> create(String id, Trip value) async {
    await _supabase.from(SupabaseConfig.tripsTable).upsert({
      'id': id,
      'data': value.copyWith(id: id).withStableItineraryIds().toMap(),
    });
  }

  @override
  Future<void> update(String id, Map<String, Object?> data) async {
    final existing = await getById(id);
    if (existing == null) return;
    await _supabase
        .from(SupabaseConfig.tripsTable)
        .update({
          'data': {...existing.toMap(), ...data},
        })
        .eq('id', id);
  }

  @override
  Future<void> delete(String id) async {
    await _supabase.from(SupabaseConfig.tripsTable).delete().eq('id', id);
  }

  @override
  String newId() => _generateTripId();
}
