import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/enums/ai_privacy_level.dart';
import '../providers/ai_coach_providers.dart';

/// Roadmap Item 14 section 23/14B: the user-facing control over how much
/// the AI Coach ever sees, including turning it off entirely. Persisted
/// via [setAiPrivacyLevel] — a restart restores whatever was last
/// chosen (see [aiPrivacyBootstrapProvider]). Wired into [ProfilePage].
class AiPrivacySettingsTile extends ConsumerWidget {
  const AiPrivacySettingsTile({super.key});

  static const _labels = {
    AiPrivacyLevel.fullContext: 'Full — sees your progress and mission details',
    AiPrivacyLevel.limitedContext: 'Limited — sees only today\'s mission',
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
          // `ForgeCard` (the usual host for this widget) paints its own
          // background via a plain `DecoratedBox`, not a `Material` —
          // without this, `RadioListTile`'s ink/selection painting has
          // no real Material ancestor to target and Flutter flags it.
          Material(
            type: MaterialType.transparency,
            child: RadioGroup<AiPrivacyLevel>(
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  unawaited(setAiPrivacyLevel(ref, value));
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
          ),
        ],
      ),
    );
  }
}
