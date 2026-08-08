import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/forge_tokens.dart';
import '../../../shared/utils/forge_validators.dart';
import '../../../shared/widgets/forge_button.dart';
import '../../../shared/widgets/forge_password_field.dart';
import '../../../shared/widgets/forge_scaffold.dart';
import '../../../shared/widgets/forge_text_field.dart';
import 'auth_state.dart';
import 'auth_state_notifier.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/auth_header.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final pendingEmail = ref.read(authStateNotifierProvider).pendingEmail;
    _emailController = TextEditingController(text: pendingEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Reentrancy guard: read (not watch) so this is a synchronous check
    // independent of the next build, preventing a double-tap from firing
    // two overlapping sign-in attempts.
    if (ref.read(authStateNotifierProvider).status ==
        AuthStatus.authenticating) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    await ref
        .read(authStateNotifierProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateNotifierProvider);
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final isSubmitting = authState.status == AuthStatus.authenticating;

    ref.listen<AuthState>(authStateNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.failure) {
        _passwordController.clear();
      }
    });

    return ForgeScaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.space6),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeader(
                title: 'Welcome back',
                subtitle: 'Sign in to continue your streak.',
              ),
              SizedBox(height: tokens.spacing.space6),
              if (authState.status == AuthStatus.failure &&
                  authState.failure != null) ...[
                AuthErrorBanner(failure: authState.failure!),
                SizedBox(height: tokens.spacing.space4),
              ],
              ForgeTextField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: ForgeValidators.email,
                enabled: !isSubmitting,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              SizedBox(height: tokens.spacing.space4),
              ForgePasswordField(
                label: 'Password',
                controller: _passwordController,
                focusNode: _passwordFocus,
                textInputAction: TextInputAction.done,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Password is required.'
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => context.pushNamed(AppRouteNames.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),
              SizedBox(height: tokens.spacing.space4),
              ForgeButton(
                label: isSubmitting ? 'Signing in…' : 'Sign In',
                onPressed: isSubmitting ? null : _submit,
              ),
              SizedBox(height: tokens.spacing.space4),
              Center(
                child: TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => context.goNamed(AppRouteNames.signUp),
                  child: const Text("Don't have an account? Sign up"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
