import 'dart:async';

import 'package:kalsada/data/repository/auth_repository.dart';

/// Scriptable in-memory [AuthRepository] for tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    String? initialUserId,
    this.signUpCreatesSession = true,
    this.failWith,
  }) : _userId = initialUserId;

  String? _userId;

  /// When false, signUp simulates the email-confirmation flow.
  final bool signUpCreatesSession;

  /// When set, every operation throws this failure.
  final AuthFailure? failWith;

  final StreamController<String?> _controller = StreamController.broadcast();

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> watchUserId() => _controller.stream;

  /// The full name passed to the most recent signUp call.
  String? lastSignUpFullName;

  /// Emails passed to sendPasswordReset.
  final List<String> passwordResets = [];

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    if (failWith != null) throw failWith!;
    lastSignUpFullName = fullName;
    if (!signUpCreatesSession) return false;
    _userId = 'user-$email';
    _controller.add(_userId);
    return true;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (failWith != null) throw failWith!;
    passwordResets.add(email);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (failWith != null) throw failWith!;
    _userId = 'user-$email';
    _controller.add(_userId);
  }

  @override
  Future<void> signOut() async {
    if (failWith != null) throw failWith!;
    _userId = null;
    _controller.add(null);
  }

  /// Simulates an external auth event such as token expiry or another tab
  /// signing out, without calling [AuthStore.signOut].
  void emitUserId(String? userId) {
    _userId = userId;
    _controller.add(userId);
  }

  void close() => _controller.close();
}
