import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';

/// Accessibility status — informational only. Forge already reduces
/// motion automatically wherever animation happens (Daily Transmission,
/// dashboard snapshots, the level-up celebration — see
/// `MediaQuery.of(context).disableAnimations`, read directly at each of
/// those call sites from the platform's own accessibility setting), so
/// this deliberately does not add a second, in-app override toggle:
/// that would mean two sources of truth for the same behavior, and the
/// platform setting is already the more discoverable, OS-consistent
/// place a user goes to control this. Text size similarly already
/// follows the system's own scale via ordinary `MediaQuery` inheritance
/// — Forge doesn't offer a separate in-app text-size override, so
/// there's nothing further to add here without inventing a control with
/// no real effect.
class SettingsAccessibilitySection extends StatelessWidget {
  const SettingsAccessibilitySection({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accessibility', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: tokens.spacing.space1),
        Semantics(
          label: reducedMotion
              ? 'Reduced motion is on, following your device setting'
              : 'Reduced motion is off, following your device setting',
          excludeSemantics: true,
          child: Row(
            children: [
              Icon(
                reducedMotion
                    ? Icons.motion_photos_off_outlined
                    : Icons.motion_photos_auto_outlined,
                size: 18,
                color: tokens.text.withValues(alpha: 0.7),
              ),
              SizedBox(width: tokens.spacing.space2),
              Expanded(
                child: Text(
                  reducedMotion
                      ? 'Reduced motion is on (following your device setting)'
                      : 'Reduced motion is off (following your device setting)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.text.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.space1),
        Text(
          'Text size also follows your device\'s display settings.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.text.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
