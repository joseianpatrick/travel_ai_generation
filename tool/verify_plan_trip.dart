// Verifies the live `plan-trip` edge function over raw HTTP.
//
//   dart run tool/verify_plan_trip.dart                 # unauth check + sign-up
//   dart run tool/verify_plan_trip.dart <email> <pass>  # sign in + full run
//
// The no-arg form checks that unauthenticated calls are rejected and creates
// a throwaway user. With email confirmation enabled, confirm the user (SQL:
// update auth.users set email_confirmed_at = now() where email = ...) and
// rerun with the printed credentials for the authenticated end-to-end call.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kalsada/data/sample_trips.dart';
import 'package:kalsada/data/supabase/supabase_config.dart';
import 'package:kalsada/data/trip.dart';

final HttpClient _http = HttpClient();

Future<(int, Map<String, dynamic>)> _post(
  String path,
  Map<String, dynamic> body, {
  String? bearer,
}) async {
  final request = await _http.postUrl(Uri.parse('${SupabaseConfig.url}$path'));
  request.headers.contentType = ContentType.json;
  request.headers.set('apikey', SupabaseConfig.publishableKey);
  if (bearer != null) {
    request.headers.set('Authorization', 'Bearer $bearer');
  }
  request.write(jsonEncode(body));
  final response = await request.close();
  final text = await utf8.decodeStream(response);
  final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
  return (
    response.statusCode,
    decoded is Map<String, dynamic> ? decoded : {'raw': decoded},
  );
}

Future<void> main(List<String> args) async {
  if (!SupabaseConfig.isConfigured) {
    stderr.writeln('FAIL: SupabaseConfig still holds placeholder values.');
    exit(1);
  }
  var failed = false;

  Future<void> check(
    String label,
    Future<void> Function() body, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      await body().timeout(timeout);
      stdout.writeln('OK   $label');
    } catch (error) {
      failed = true;
      stderr.writeln('FAIL $label: $error');
    }
  }

  await check('unauthenticated invoke is rejected with 401', () async {
    final request = await _http.postUrl(
      Uri.parse('${SupabaseConfig.url}/functions/v1/plan-trip'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'prompt': 'test'}));
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode != 401) {
      throw StateError('expected 401, got ${response.statusCode}');
    }
  });

  if (args.length < 2) {
    // Plus-alias of a real inbox: passes email validation, and confirmation
    // is done via SQL so no email ever needs to be opened.
    final inbox = Platform.environment['VERIFY_EMAIL'];
    if (inbox == null || !inbox.contains('@')) {
      stderr.writeln(
        'Set VERIFY_EMAIL=you@example.com (a real inbox; a plus-alias of it '
        'is used for the throwaway user) or rerun with <email> <password>.',
      );
      exit(1);
    }
    final email = inbox.replaceFirst(
      '@',
      '+kalsada.verify.${DateTime.now().millisecondsSinceEpoch}@',
    );
    const password = 'Verify-Kalsada-1';
    await check('throwaway user signs up', () async {
      final (status, body) = await _post('/auth/v1/signup', {
        'email': email,
        'password': password,
      });
      if (status != 200 || body['id'] == null && body['user'] == null) {
        throw StateError('signup failed ($status): $body');
      }
    });
    stdout.writeln('Created test user: $email / $password');
    stdout.writeln(
      'Confirm it (email_confirmed_at) and rerun with those credentials.',
    );
    exit(failed ? 1 : 0);
  }

  String? accessToken;
  await check('test user signs in', () async {
    final (status, body) = await _post('/auth/v1/token?grant_type=password', {
      'email': args[0],
      'password': args[1],
    });
    accessToken = body['access_token'] as String?;
    if (status != 200 || accessToken == null) {
      throw StateError('sign-in failed ($status): $body');
    }
  });

  if (accessToken != null) {
    await check('Gemini plans a real trip end-to-end', () async {
      final (status, data) = await _post('/functions/v1/plan-trip', {
        'prompt': '3-day Vigan heritage ride for 2 riders',
      }, bearer: accessToken);
      if (status != 200) {
        throw StateError('plan-trip failed ($status): $data');
      }
      final trip = Trip.fromMap(data['trip'] as Map<String, dynamic>);
      if (trip.name.isEmpty || trip.days.isEmpty) {
        throw StateError('incomplete trip: ${data['trip']}');
      }
      final day = trip.days.first;
      if (day.latitude == 0 || day.longitude == 0) {
        throw StateError('day 1 has no coordinates: ${day.toMap()}');
      }
      if (trip.budgetItems.isEmpty || trip.gearItems.isEmpty) {
        throw StateError('missing budget or gear: ${data['trip']}');
      }
      stdout.writeln(
        '     → "${trip.name}" · ${trip.days.length} days · '
        '${trip.distanceTotal} · ${trip.totalPerRider}/rider',
      );
      stdout.writeln('     → ${data['summary']}');
    }, timeout: const Duration(seconds: 120));

    await check(
      'options steer the plan (car · 4 riders · no expressways)',
      () async {
        final (status, data) = await _post('/functions/v1/plan-trip', {
          'prompt': 'Ilocos coastal loop',
          'options': {
            'travelMode': 'car',
            'avoidExpressways': true,
            'groupSize': 4,
            'pace': 'packed',
          },
        }, bearer: accessToken);
        if (status != 200) {
          throw StateError('plan-trip failed ($status): $data');
        }
        final trip = Trip.fromMap(data['trip'] as Map<String, dynamic>);
        if (trip.riders.length != 4) {
          throw StateError('expected 4 riders, got ${trip.riders.length}');
        }
        // The nights-duplication fix: datesLabel must be the date range only.
        if (trip.datesLabel.toLowerCase().contains('night')) {
          throw StateError('datesLabel still has "night": ${trip.datesLabel}');
        }
        stdout.writeln(
          '     → "${trip.name}" · ${trip.riders.length} riders · '
          '${trip.datesLabel}',
        );
      },
      timeout: const Duration(seconds: 120),
    );

    await check(
      'AI refine revises an existing trip in place',
      () async {
        final (status, data) = await _post('/functions/v1/plan-trip', {
          'prompt': 'make it cheaper',
          'options': {'baseTrip': SampleTrips.palawan().toMap()},
        }, bearer: accessToken);
        if (status != 200) {
          throw StateError('refine failed ($status): $data');
        }
        final trip = Trip.fromMap(data['trip'] as Map<String, dynamic>);
        if (trip.name.isEmpty || trip.days.isEmpty) {
          throw StateError('incomplete revised trip: ${data['trip']}');
        }
        stdout.writeln(
          '     → revised "${trip.name}" · ${trip.totalPerRider}/rider',
        );
      },
      timeout: const Duration(seconds: 120),
    );
  }

  if (failed) {
    stderr.writeln('plan-trip verification FAILED');
    exit(1);
  }
  stdout.writeln('plan-trip verification passed.');
  exit(0);
}
