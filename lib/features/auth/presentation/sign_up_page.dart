import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/forge_colors.dart';
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

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final pendingEmail = ref.read(authStateNotifierProvider).pendingEmail;
    _emailController = TextEditingController(text: pendingEmail ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authStateNotifierProvider).status ==
        AuthStatus.authenticating) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    await ref
        .read(authStateNotifierProvider.notifier)
        .signUp(
          displayName: _displayNameController.text,
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
        _confirmPasswordController.clear();
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
                title: 'Prove you can.',
                subtitle: 'Create an account to start your first streak.',
              ),
              SizedBox(height: tokens.spacing.space6),
              if (authState.status == AuthStatus.failure &&
                  authState.failure != null) ...[
                AuthErrorBanner(failure: authState.failure!),
                SizedBox(height: tokens.spacing.space4),
              ],
              ForgeTextField(
                label: 'Display name',
                controller: _displayNameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                validator: ForgeValidators.displayName,
                enabled: !isSubmitting,
                onFieldSubmitted: (_) => _emailFocus.requestFocus(),
              ),
              SizedBox(height: tokens.spacing.space4),
              ForgeTextField(
                label: 'Email',
                controller: _emailController,
                focusNode: _emailFocus,
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
                textInputAction: TextInputAction.next,
                validator: ForgeValidators.password,
                isNewPassword: true,
                onFieldSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
              ),
              SizedBox(height: tokens.spacing.space2),
              Text(
                'At least ${ForgeValidators.passwordMinLength} characters — length '
                'matters more than symbols.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.text.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              SizedBox(height: tokens.spacing.space4),
              ForgePasswordField(
                label: 'Confirm password',
                controller: _confirmPasswordController,
                focusNode: _confirmPasswordFocus,
                textInputAction: TextInputAction.done,
                isNewPassword: true,
                validator: (value) => ForgeValidators.matchesPassword(
                  value,
                  _passwordController.text,
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
              SizedBox(height: tokens.spacing.space4),
              _TermsAcceptanceField(enabled: !isSubmitting),
              SizedBox(height: tokens.spacing.space4),
              ForgeButton(
                label: isSubmitting ? 'Creating account…' : 'Create Account',
                onPressed: isSubmitting ? null : _submit,
              ),
              SizedBox(height: tokens.spacing.space4),
              Center(
                child: TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => context.goNamed(AppRouteNames.signIn),
                  child: const Text('Already have an account? Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsAcceptanceField extends StatelessWidget {
  const _TermsAcceptanceField({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return FormField<bool>(
      initialValue: false,
      validator: (value) => (value ?? false)
          ? null
          : 'You must accept the Terms of Service and Privacy Policy to continue.',
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: enabled
                  ? () => state.didChange(!(state.value ?? false))
                  : null,
              borderRadius: tokens.radius.mdRadius,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.space1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: state.value ?? false,
                      onChanged: enabled ? (v) => state.didChange(v) : null,
                    ),
                    Expanded(
                      child: Text(
                        'I agree to the Terms of Service and Privacy Policy.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: EdgeInsets.only(
                  left: tokens.spacing.space3,
                  top: tokens.spacing.space1,
                ),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(
                    color: ForgeColors.danger,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
