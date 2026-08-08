import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';

/// The kicker + title header shared by every auth screen (splash aside),
/// mirroring the mockup's `h6` kicker / `h1` heading pattern.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FORGE', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: tokens.spacing.space2),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null) ...[
          SizedBox(height: tokens.spacing.space2),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.text.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}
