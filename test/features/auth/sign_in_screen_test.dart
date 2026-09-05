import 'package:kalsada/dependency/dependency_manager.dart';
import 'package:kalsada/features/auth/auth_store.dart';
import 'package:kalsada/features/auth/sign_in_screen.dart';
import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../support/finders.dart';

void main() {
  late FakeAuthRepository repository;

  setUp(() async {
    await sl.reset();
    repository = FakeAuthRepository();
    final store = AuthStore(authRepository: repository)..initialize();
    sl.registerSingleton(store);
  });

  tearDown(() async {
    sl<AuthStore>().dispose();
    repository.close();
    await sl.reset();
  });

  Widget app() => MaterialApp(
    theme: kalsadaTheme(Brightness.light),
    home: const SignInScreen(),
  );

  testWidgets('renders the form', (tester) async {
    await tester.pumpWidget(app());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(findLabel('Email address'), findsOneWidget);
    expect(findLabel('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(findLabel('Sign In'), findsOneWidget);
  });

  testWidgets('invalid input shows a validation error', (tester) async {
    await tester.pumpWidget(app());

    await tester.enterText(find.byType(TextField).first, 'nope');
    await tester.enterText(find.byType(TextField).last, 'secret123');
    await tester.tap(findLabel('Sign In'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('valid credentials sign the user in', (tester) async {
    await tester.pumpWidget(app());

    await tester.enterText(find.byType(TextField).first, 'a@b.co');
    await tester.enterText(find.byType(TextField).last, 'secret123');
    await tester.tap(findLabel('Sign In'));
    await tester.pump();
    await tester.pump();

    expect(sl<AuthStore>().status, AuthStatus.signedIn);
  });
}
