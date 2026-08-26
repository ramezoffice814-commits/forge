import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';

/// App identity — deliberately minimal. No legal/privacy links are
/// shown here because no such page or route exists anywhere in this
/// app yet; adding a placeholder link to nothing would be worse than
/// omitting the section entirely. The version string is a plain
/// constant, not read from a package (no `package_info_plus` dependency
/// exists in this project) — keep it in sync with `pubspec.yaml`'s
/// `version:` field by hand when that changes.
class SettingsAboutSection extends StatelessWidget {
  const SettingsAboutSection({super.key});

  static const _version = '1.0.0+1';

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: tokens.spacing.space1),
        Text('Forge', style: Theme.of(context).textTheme.bodyMedium),
        Text(
          'Version $_version',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.text.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
