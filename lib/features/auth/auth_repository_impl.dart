import 'dart:async';
import 'dart:developer' as developer;

import 'package:base_project/data/repository/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed email/password authentication.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({this.clientOverride});

  /// Client injected in tests; production resolves the global instance.
  final GoTrueClient? clientOverride;

  GoTrueClient get _auth => clientOverride ?? Supabase.instance.client.auth;

  @override
  String? get currentUserId => _auth.currentSession?.user.id;

  @override
  Stream<String?> watchUserId() =>
      _auth.onAuthStateChange.map((state) => state.session?.user.id);

  static const String _networkErrorMessage =
      'Network error. Check your connection and try again.';
  static const String _genericErrorMessage =
      'Something went wrong. Please try again.';

  /// Runs [action], translating any failure into a user-safe [AuthFailure].
  /// GoTrue's [AuthException.message] is written for logs, not end users
  /// (e.g. "Invalid login credentials", raw rate-limit second-counts), so
  /// it's mapped to friendly copy here rather than shown as-is. The raw
  /// error is always logged first so the real cause isn't lost.
  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthRetryableFetchException catch (error, stackTrace) {
      // GoTrue's HTTP layer catches every transport-level failure (a dropped
      // socket, DNS lookup failure, timeout, ...) and rethrows it as this
      // type rather than letting the original exception (e.g.
      // SocketException) escape — so network errors have to be recognized
      // by this type, not by catching dart:io exceptions directly.
      developer.log(
        'Auth network error',
        name: 'SupabaseAuthRepository',
        error: error,
        stackTrace: stackTrace,
      );
      throw AuthFailure(_networkErrorMessage);
    } on AuthException catch (error, stackTrace) {
      developer.log(
        'Auth error: ${error.message}',
        name: 'SupabaseAuthRepository',
        error: error,
        stackTrace: stackTrace,
      );
      throw AuthFailure(_friendlyMessage(error));
    } catch (error, stackTrace) {
      developer.log(
        'Unexpected auth error',
        name: 'SupabaseAuthRepository',
        error: error,
        stackTrace: stackTrace,
      );
      throw AuthFailure(_genericErrorMessage);
    }
  }

  String _friendlyMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (message.contains('user already registered')) {
      return 'An account with this email already exists. Try signing in '
          'instead.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please confirm your email before signing in — check your '
          'inbox.';
    }
    if (message.contains('rate limit') ||
        message.contains('can only request this after')) {
      return "You're doing that a bit too fast — wait a moment and try "
          'again.';
    }
    if (message.contains('password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    return _genericErrorMessage;
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
  }) => _run(() async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      // Display-only metadata; never used for authorization decisions.
      data: fullName == null || fullName.isEmpty
          ? null
          : {'full_name': fullName},
    );
    return response.session != null;
  });

  @override
  Future<void> signIn({required String email, required String password}) =>
      _run(() => _auth.signInWithPassword(email: email, password: password));

  @override
  Future<void> signOut() => _run(() => _auth.signOut());

  @override
  Future<void> sendPasswordReset(String email) =>
      _run(() => _auth.resetPasswordForEmail(email));
}

/// In-memory auth used while Supabase credentials are placeholders: any
/// well-formed credentials sign in successfully.
class LocalAuthRepository implements AuthRepository {
  String? _userId;
  final StreamController<String?> _controller = StreamController.broadcast();

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> watchUserId() => _controller.stream;

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    _userId = 'local-user';
    _controller.add(_userId);
    return true;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    _userId = 'local-user';
    _controller.add(_userId);
  }

  @override
  Future<void> signOut() async {
    _userId = null;
    _controller.add(null);
  }

  @override
  Future<void> sendPasswordReset(String email) async {}
}
