import 'package:flutter/material.dart';

import '../../core/theme/forge_tokens.dart';
import 'forge_button.dart';

/// Reusable global "retry" state — for content that simply didn't load
/// (e.g. a stale cache miss) rather than a hard error; [onRetry] is
/// required, since without it this state has no purpose.
class ForgeRetryState extends StatelessWidget {
  const ForgeRetryState({
    super.key,
    required this.onRetry,
    this.title = "Couldn't load this",
    this.message,
  });

  final VoidCallback onRetry;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 40, color: tokens.accent),
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
            SizedBox(height: tokens.spacing.space4),
            ForgeButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
