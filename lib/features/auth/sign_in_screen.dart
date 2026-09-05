import 'package:base_project/dependency/dependency_manager.dart';
import 'package:base_project/features/auth/auth_store.dart';
import 'package:base_project/features/auth/widgets/auth_widgets.dart';
import 'package:base_project/shared/widgets/circle_icon_button.dart';
import 'package:base_project/shared/widgets/primary_button.dart';
import 'package:base_project/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    sl<AuthStore>().clearError();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    sl<AuthStore>().signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    final authStore = sl<AuthStore>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleIconButton(
                icon: Icons.arrow_back_ios_new,
                tooltip: 'Back',
                onPressed: () => context.goNamed('onboarding'),
              ),
              const SizedBox(height: 28),
              Text(
                'Welcome back',
                style: kalsadaHeadline(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sign in to pick up your trips where you left off.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: colors.sub,
                ),
              ),
              const SizedBox(height: 28),
              AuthTextField(
                controller: _emailController,
                label: 'Email address',
                hint: 'rider@kalsada.app',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _passwordController,
                label: 'Password',
                obscure: true,
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => sl<AuthStore>()
                      .sendPasswordReset(_emailController.text),
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ),
              ),
              Observer(
                builder: (context) =>
                    AuthErrorText(message: authStore.errorMessage),
              ),
              Observer(
                builder: (context) {
                  if (authStore.infoMessage.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      authStore.infoMessage,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Observer(
                builder: (context) => PrimaryButton(
                  label: 'Sign In',
                  isLoading: authStore.isLoading,
                  onPressed: _submit,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => context.goNamed('signup'),
                  child: Text(
                    'New to Kalsada? Create an account',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
