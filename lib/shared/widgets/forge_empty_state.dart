import 'package:flutter/material.dart';

import '../../core/theme/forge_tokens.dart';

/// Reusable global "empty" state — an icon, a title, an optional message,
/// and an optional action (e.g. a button to create the first item).
class ForgeEmptyState extends StatelessWidget {
  const ForgeEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: tokens.neutralRamp.c500),
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
            if (action != null) ...[
              SizedBox(height: tokens.spacing.space4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
