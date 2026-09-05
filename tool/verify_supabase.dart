// Verifies the live Supabase project with the pure-Dart client:
//   dart run tool/verify_supabase.dart
//
// With per-user RLS in place, the anon role must be able to read the shared
// demo trip (user_id is null) but must NOT be able to write anything.
import 'dart:async';
import 'dart:io';

import 'package:kalsada/data/sample_trips.dart';
import 'package:kalsada/data/supabase/supabase_config.dart';
import 'package:kalsada/data/trip.dart';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  if (!SupabaseConfig.isConfigured) {
    stderr.writeln('FAIL: SupabaseConfig still holds placeholder values.');
    exit(1);
  }
  final client = SupabaseClient(
    SupabaseConfig.url,
    SupabaseConfig.publishableKey,
  );
  var failed = false;

  Future<void> check(String label, Future<void> Function() body) async {
    try {
      await body().timeout(const Duration(seconds: 20));
      stdout.writeln('OK   $label');
    } catch (error) {
      failed = true;
      stderr.writeln('FAIL $label: $error');
    }
  }

  final seed = SampleTrips.palawan();

  await check('anon can read the shared demo trip', () async {
    final row = await client
        .from(SupabaseConfig.tripsTable)
        .select()
        .eq('id', seed.id)
        .single();
    final trip = Trip.fromMap(row['data'] as Map<String, dynamic>);
    if (trip.name != seed.name || trip.days.length != 6) {
      throw StateError('round-trip mismatch: $row');
    }
    if (trip.days.first.latitude == 0) {
      throw StateError('seed row is stale — latitude missing');
    }
  });

  await check('realtime stream emits the shared trip', () async {
    final rows = await client
        .from(SupabaseConfig.tripsTable)
        .stream(primaryKey: ['id']).first;
    if (!rows.any((r) => r['id'] == seed.id)) {
      throw StateError('stream did not include the seed trip');
    }
  });

  await check('anon INSERT is rejected by RLS', () async {
    try {
      await client
          .from(SupabaseConfig.tripsTable)
          .insert({'id': 'anon-should-fail', 'data': seed.toMap()});
      throw StateError('insert unexpectedly succeeded — RLS is too open');
    } on PostgrestException {
      // Expected: no insert policy for anon.
    }
  });

  await check('anon UPDATE is silently filtered by RLS', () async {
    final rows = await client
        .from(SupabaseConfig.tripsTable)
        .update({'data': seed.toMap()})
        .eq('id', seed.id)
        .select();
    if (rows.isNotEmpty) {
      throw StateError('update unexpectedly affected rows — RLS is too open');
    }
  });

  await check('anon DELETE is silently filtered by RLS', () async {
    await client.from(SupabaseConfig.tripsTable).delete().eq('id', seed.id);
    final row = await client
        .from(SupabaseConfig.tripsTable)
        .select('id')
        .eq('id', seed.id)
        .maybeSingle();
    if (row == null) {
      throw StateError('delete removed the shared trip — RLS is too open');
    }
  });

  await client.dispose();
  if (failed) {
    stderr.writeln('Supabase verification FAILED');
    exit(1);
  }
  stdout.writeln('Supabase verification passed.');
  exit(0);
}
