import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/enums/ai_privacy_level.dart';
import '../providers/ai_coach_providers.dart';

/// Roadmap Item 14 section 23: the user-facing control over how much
/// context the AI Coach ever sees, including turning it off entirely.
/// Not yet wired into a settings screen (this app doesn't have one at
/// the time this widget was written) — drop this into whichever screen
/// hosts app settings once one exists.
class AiPrivacySettingsTile extends ConsumerWidget {
  const AiPrivacySettingsTile({super.key});

  static const _labels = {
    AiPrivacyLevel.fullContext:
        'Full — the Watcher sees progress and mission details',
    AiPrivacyLevel.limitedContext:
        'Limited — the Watcher sees only the current mission',
    AiPrivacyLevel.disabled: 'Off — no AI coaching',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final current = ref.watch(aiPrivacyLevelProvider);

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Coach', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: tokens.spacing.space1),
          RadioGroup<AiPrivacyLevel>(
            groupValue: current,
            onChanged: (value) {
              if (value != null) {
                ref.read(aiPrivacyLevelProvider.notifier).state = value;
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final level in AiPrivacyLevel.values)
                  RadioListTile<AiPrivacyLevel>(
                    contentPadding: EdgeInsets.zero,
                    value: level,
                    title: Text(
                      _labels[level]!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
