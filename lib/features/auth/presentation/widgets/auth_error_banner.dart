import 'package:flutter/material.dart';

import '../../../../core/theme/forge_colors.dart';
import '../../../../core/theme/forge_tokens.dart';
import '../../domain/auth_failure.dart';
import '../auth_failure_copy.dart';

/// Inline error banner shown near the top of an auth form. Color alone
/// never carries the meaning — an icon and the message text do the work,
/// the danger tint is just reinforcement.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.failure});

  final AuthFailure failure;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final message = authFailureMessage(failure);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.space3,
          vertical: tokens.spacing.space3,
        ),
        decoration: BoxDecoration(
          color: ForgeColors.danger.withValues(alpha: 0.12),
          borderRadius: tokens.radius.mdRadius,
          border: Border.all(color: ForgeColors.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline,
              color: ForgeColors.danger,
              size: 18,
            ),
            SizedBox(width: tokens.spacing.space2),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
