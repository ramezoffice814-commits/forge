import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/forge_tokens.dart';
import '../../../shared/utils/forge_validators.dart';
import '../../../shared/widgets/forge_button.dart';
import '../../../shared/widgets/forge_scaffold.dart';
import '../../../shared/widgets/forge_text_field.dart';
import '../domain/auth_failure.dart';
import 'auth_usecase_providers.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/auth_header.dart';

enum _ResetStatus { idle, submitting, success, error }

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  _ResetStatus _status = _ResetStatus.idle;
  AuthFailure? _failure;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_status == _ResetStatus.submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _status = _ResetStatus.submitting;
      _failure = null;
    });
    try {
      await ref
          .read(requestPasswordResetUseCaseProvider)
          .call(_emailController.text);
      if (mounted) setState(() => _status = _ResetStatus.success);
    } on ForgeAuthException catch (e) {
      if (mounted) {
        setState(() {
          _status = _ResetStatus.error;
          _failure = e.failure;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = _ResetStatus.error;
          _failure = const UnknownAuthFailure();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final isSubmitting = _status == _ResetStatus.submitting;

    return ForgeScaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              title: 'Reset your password',
              subtitle:
                  "Enter your account's email — we'll send instructions if it matches an account.",
            ),
            SizedBox(height: tokens.spacing.space6),
            if (_status == _ResetStatus.error && _failure != null) ...[
              AuthErrorBanner(failure: _failure!),
              SizedBox(height: tokens.spacing.space4),
            ],
            if (_status == _ResetStatus.success)
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: EdgeInsets.all(tokens.spacing.space4),
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.12),
                    borderRadius: tokens.radius.mdRadius,
                    border: Border.all(
                      color: tokens.accent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    "If an account exists for that email, we've sent reset "
                    'instructions. Check your inbox.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ForgeTextField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      validator: ForgeValidators.email,
                      enabled: !isSubmitting,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    SizedBox(height: tokens.spacing.space4),
                    ForgeButton(
                      label: isSubmitting
                          ? 'Sending…'
                          : 'Send Reset Instructions',
                      onPressed: isSubmitting ? null : _submit,
                    ),
                  ],
                ),
              ),
            SizedBox(height: tokens.spacing.space4),
            Center(
              child: TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back to sign in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
