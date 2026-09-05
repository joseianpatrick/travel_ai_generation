import 'dart:async';

import 'package:base_project/data/repository/auth_repository.dart';
import 'package:mobx/mobx.dart';

part 'auth_store.g.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthStore = _AuthStoreBase with _$AuthStore;

abstract class _AuthStoreBase with Store {
  _AuthStoreBase({required this.authRepository});

  final AuthRepository authRepository;

  @observable
  AuthStatus status = AuthStatus.unknown;

  @observable
  bool isLoading = false;

  @observable
  String errorMessage = '';

  /// True after a sign-up that requires the user to confirm their email.
  @observable
  bool awaitingConfirmation = false;

  /// Non-error feedback, e.g. "password reset email sent".
  @observable
  String infoMessage = '';

  StreamSubscription<String?>? _streamSubscription;
  String? _knownUserId;
  Future<void> _transitionChain = Future<void>.value();

  /// Invoked with the outgoing user's id after every user transition,
  /// including token expiry and external sign-out. Set once by DI.
  Future<void> Function(String?)? onSignedOut;

  @computed
  bool get isSignedIn => status == AuthStatus.signedIn;

  @action
  void initialize() {
    _knownUserId = authRepository.currentUserId;
    status = _knownUserId == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    _streamSubscription?.cancel();
    _streamSubscription = authRepository.watchUserId().listen((userId) {
      unawaited(_queueUserTransition(userId));
    });
  }

  Future<void> _queueUserTransition(String? userId) {
    final outgoingUserId = _knownUserId;
    _knownUserId = userId;
    runInAction(() {
      status = userId == null ? AuthStatus.signedOut : AuthStatus.signedIn;
      if (userId != null) awaitingConfirmation = false;
    });
    if (outgoingUserId != null && outgoingUserId != userId) {
      _transitionChain = _transitionChain.catchError((_) {}).then((_) async {
        try {
          await onSignedOut?.call(outgoingUserId);
        } catch (_) {
          runInAction(() {
            errorMessage =
                'Signed out, but some offline data could not be cleared.';
          });
        }
      });
    }
    return _transitionChain;
  }

  String _validate(String email, String password) {
    if (email.trim().isEmpty || !email.contains('@')) {
      return 'Enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return '';
  }

  @action
  Future<void> signIn({required String email, required String password}) async {
    infoMessage = '';
    errorMessage = _validate(email, password);
    if (errorMessage.isNotEmpty) return;
    isLoading = true;
    try {
      await authRepository.signIn(email: email.trim(), password: password);
    } on AuthFailure catch (failure) {
      runInAction(() => errorMessage = failure.message);
    } finally {
      runInAction(() => isLoading = false);
    }
  }

  @action
  Future<void> signUp({
    required String email,
    required String password,
    String fullName = '',
  }) async {
    infoMessage = '';
    errorMessage = _validate(email, password);
    if (errorMessage.isNotEmpty) return;
    isLoading = true;
    awaitingConfirmation = false;
    try {
      final signedIn = await authRepository.signUp(
        email: email.trim(),
        password: password,
        fullName: fullName.trim(),
      );
      if (!signedIn) {
        runInAction(() => awaitingConfirmation = true);
      }
    } on AuthFailure catch (failure) {
      runInAction(() => errorMessage = failure.message);
    } finally {
      runInAction(() => isLoading = false);
    }
  }

  @action
  Future<void> signOut() async {
    try {
      await authRepository.signOut();
      // Auth streams can emit before or after signOut() resolves. Queueing a
      // second transition is harmless and makes this action await any cleanup
      // already triggered by that stream emission.
      await _queueUserTransition(null);
    } on AuthFailure catch (failure) {
      runInAction(() => errorMessage = failure.message);
    }
  }

  @action
  Future<void> sendPasswordReset(String email) async {
    infoMessage = '';
    if (email.trim().isEmpty || !email.contains('@')) {
      errorMessage = 'Enter your email above, then tap Forgot password.';
      return;
    }
    errorMessage = '';
    try {
      await authRepository.sendPasswordReset(email.trim());
      runInAction(
        () => infoMessage = 'Password reset email sent — check your inbox.',
      );
    } on AuthFailure catch (failure) {
      runInAction(() => errorMessage = failure.message);
    }
  }

  @action
  void clearError() {
    errorMessage = '';
    infoMessage = '';
  }

  void dispose() {
    _streamSubscription?.cancel();
  }
}
