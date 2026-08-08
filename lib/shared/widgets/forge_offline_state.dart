import 'package:flutter/material.dart';

import '../../core/theme/forge_tokens.dart';
import 'forge_button.dart';

/// Reusable global "offline" state — distinct from [ForgeErrorState]:
/// connectivity loss isn't a failure to render, it's an expected condition
/// the offline-first architecture should degrade gracefully through.
class ForgeOfflineState extends StatelessWidget {
  const ForgeOfflineState({
    super.key,
    this.title = "You're offline",
    this.message = "Some features may be unavailable until you're back online.",
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
            Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: tokens.neutralRamp.c500,
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
                label: 'Try again',
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
