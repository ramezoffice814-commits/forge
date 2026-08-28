import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/forge_tokens.dart';

/// App identity plus links to the (draft, pending-review) legal
/// surfaces added in Roadmap Item 19 — real routes now exist
/// (`PrivacyPolicyPage`/`TermsOfServicePage`), so this section links to
/// them instead of omitting the links entirely as it did before those
/// routes existed. The version string is a plain constant, not read
/// from a package (no `package_info_plus` dependency exists in this
/// project) — keep it in sync with `pubspec.yaml`'s `version:` field by
/// hand when that changes.
///
/// Roadmap Item 22: "CAN Beta" here is the one restrained beta
/// indicator this item's own instruction calls for ("do not plaster
/// 'beta' across every screen — Settings/About is sufficient") — no
/// other screen carries a beta label.
class SettingsAboutSection extends StatelessWidget {
  const SettingsAboutSection({super.key});

  static const _version = '1.0.0-beta.1+5';

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: tokens.spacing.space1),
        Text('CAN Beta', style: Theme.of(context).textTheme.bodyMedium),
        Text(
          'Version $_version',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.text.withValues(alpha: 0.6),
          ),
        ),
        SizedBox(height: tokens.spacing.space2),
        Wrap(
          spacing: tokens.spacing.space2,
          children: [
            TextButton(
              onPressed: () => context.pushNamed(AppRouteNames.privacyPolicy),
              child: const Text('Privacy'),
            ),
            TextButton(
              onPressed: () => context.pushNamed(AppRouteNames.termsOfService),
              child: const Text('Terms of Service'),
            ),
          ],
        ),
      ],
    );
  }
}
