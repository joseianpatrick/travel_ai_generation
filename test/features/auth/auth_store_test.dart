import 'package:kalsada/data/repository/auth_repository.dart';
import 'package:kalsada/features/auth/auth_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_auth_repository.dart';

void main() {
  test('initialize reflects an existing session', () {
    final repository = FakeAuthRepository(initialUserId: 'u1');
    final store = AuthStore(authRepository: repository);
    store.initialize();

    expect(store.status, AuthStatus.signedIn);
    expect(store.isSignedIn, isTrue);

    store.dispose();
    repository.close();
  });

  test('initialize with no session is signed out', () {
    final repository = FakeAuthRepository();
    final store = AuthStore(authRepository: repository);
    store.initialize();

    expect(store.status, AuthStatus.signedOut);

    store.dispose();
    repository.close();
  });

  test('signIn transitions to signedIn via the auth stream', () async {
    final repository = FakeAuthRepository();
    final store = AuthStore(authRepository: repository);
    store.initialize();

    await store.signIn(email: 'a@b.co', password: 'secret123');
    await Future<void>.delayed(Duration.zero);

    expect(store.status, AuthStatus.signedIn);
    expect(store.errorMessage, isEmpty);
    expect(store.isLoading, isFalse);

    store.dispose();
    repository.close();
  });

  test('validation rejects bad email and short password', () async {
    final repository = FakeAuthRepository();
    final store = AuthStore(authRepository: repository);
    store.initialize();

    await store.signIn(email: 'not-an-email', password: 'secret123');
    expect(store.errorMessage, contains('valid email'));

    await store.signIn(email: 'a@b.co', password: '123');
    expect(store.errorMessage, contains('at least 6'));
    expect(store.status, AuthStatus.signedOut);

    store.dispose();
    repository.close();
  });

  test('auth failures surface as errorMessage', () async {
    final repository = FakeAuthRepository(
      failWith: AuthFailure('Invalid login credentials'),
    );
    final store = AuthStore(authRepository: repository);
    store.initialize();

    await store.signIn(email: 'a@b.co', password: 'secret123');

    expect(store.errorMessage, 'Invalid login credentials');
    expect(store.status, AuthStatus.signedOut);
    expect(store.isLoading, isFalse);

    store.dispose();
    repository.close();
  });

  test('signUp without immediate session sets awaitingConfirmation', () async {
    final repository = FakeAuthRepository(signUpCreatesSession: false);
    final store = AuthStore(authRepository: repository);
    store.initialize();

    await store.signUp(email: 'a@b.co', password: 'secret123');

    expect(store.awaitingConfirmation, isTrue);
    expect(store.status, AuthStatus.signedOut);

    store.dispose();
    repository.close();
  });

  test('signOut returns to signedOut', () async {
    final repository = FakeAuthRepository(initialUserId: 'u1');
    final store = AuthStore(authRepository: repository);
    store.initialize();

    await store.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(store.status, AuthStatus.signedOut);

    store.dispose();
    repository.close();
  });

  test('external sign-out clears the outgoing user cache', () async {
    final repository = FakeAuthRepository(initialUserId: 'u1');
    final store = AuthStore(authRepository: repository);
    final clearedOwners = <String?>[];
    store.onSignedOut = (ownerId) async => clearedOwners.add(ownerId);
    store.initialize();

    repository.emitUserId(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(store.status, AuthStatus.signedOut);
    expect(clearedOwners, ['u1']);

    store.dispose();
    repository.close();
  });
}
