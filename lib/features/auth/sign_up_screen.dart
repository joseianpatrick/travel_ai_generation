import 'package:base_project/dependency/dependency_manager.dart';
import 'package:base_project/features/auth/auth_store.dart';
import 'package:base_project/features/auth/widgets/auth_widgets.dart';
import 'package:base_project/shared/widgets/circle_icon_button.dart';
import 'package:base_project/shared/widgets/primary_button.dart';
import 'package:base_project/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    sl<AuthStore>().clearError();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    sl<AuthStore>().signUp(
      email: _emailController.text,
      password: _passwordController.text,
      fullName: _nameController.text,
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
                'Create your account',
                style: kalsadaHeadline(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Just a few details to start planning rides with your crew.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: colors.sub,
                ),
              ),
              const SizedBox(height: 28),
              Observer(
                builder: (context) {
                  if (!authStore.awaitingConfirmation) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.accentSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Almost there — check your email to confirm your '
                      'account, then sign in.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  );
                },
              ),
              AuthTextField(
                controller: _nameController,
                label: 'Full name',
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 12),
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
                hint: 'Min. 6 characters',
                obscure: true,
                onSubmitted: (_) => _submit(),
              ),
              Observer(
                builder: (context) =>
                    AuthErrorText(message: authStore.errorMessage),
              ),
              const SizedBox(height: 24),
              Observer(
                builder: (context) => PrimaryButton(
                  label: 'Create Account',
                  isLoading: authStore.isLoading,
                  onPressed: _submit,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => context.goNamed('signin'),
                  child: Text(
                    'Already have an account? Sign in',
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
