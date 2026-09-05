/// Raised by [AuthRepository] implementations with a user-presentable message.
class AuthFailure implements Exception {
  AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Authentication contract the app depends on; concrete impls live in
/// `lib/features/auth/`.
abstract interface class AuthRepository {
  /// The signed-in user's id, or null when signed out.
  String? get currentUserId;

  /// Emits the user id on every auth state change (null on sign-out).
  Stream<String?> watchUserId();

  /// Creates an account. Returns true when a session was established
  /// immediately; false when the account requires email confirmation first.
  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
  });

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// Sends a password-reset email.
  Future<void> sendPasswordReset(String email);
}
