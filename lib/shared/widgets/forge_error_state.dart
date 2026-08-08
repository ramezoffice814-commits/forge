import 'package:flutter/material.dart';

import '../../core/theme/forge_colors.dart';
import '../../core/theme/forge_tokens.dart';
import 'forge_button.dart';

/// Reusable global "error" state — an icon, a title, an optional message,
/// and an optional retry action.
class ForgeErrorState extends StatelessWidget {
  const ForgeErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.onRetry,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: ForgeColors.danger,
            ),
            SizedBox(height: tokens.spacing.space3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (message != null) ...[
              SizedBox(height: tokens.spacing.space2),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.text.withValues(alpha: 0.7),
                ),
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: tokens.spacing.space4),
              ForgeButton(
                label: 'Retry',
                variant: ForgeButtonVariant.secondary,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
