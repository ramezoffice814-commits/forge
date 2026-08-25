import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/enums/ai_privacy_level.dart';
import '../providers/ai_coach_providers.dart';
import '../providers/mission_ai_insight_provider.dart';

/// AI-generated mission insight (Roadmap Item 14 section 20) — additive
/// and visually distinct from the deterministic
/// `MissionExplanationPanel`: this widget never replaces it, only sits
/// alongside it, and is entirely absent (not just empty) when the user
/// has disabled AI context.
class AiMissionInsightPanel extends ConsumerWidget {
  const AiMissionInsightPanel({
    super.key,
    required this.displayName,
    required this.missionTitle,
    required this.missionCategory,
    required this.missionDifficulty,
  });

  final String displayName;
  final String missionTitle;
  final String missionCategory;
  final String missionDifficulty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacyLevel = ref.watch(aiPrivacyLevelProvider);
    if (privacyLevel == AiPrivacyLevel.disabled) return const SizedBox.shrink();

    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final insight = ref.watch(
      missionAiInsightProvider(
        MissionAiInsightParams(
          displayName: displayName,
          missionTitle: missionTitle,
          missionCategory: missionCategory,
          missionDifficulty: missionDifficulty,
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.all(tokens.spacing.space2),
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.08),
        borderRadius: tokens.radius.mdRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 16, color: tokens.accent),
          SizedBox(width: tokens.spacing.space1),
          Expanded(
            child: insight.when(
              data: (response) => Semantics(
                label: 'AI coach insight: ${response.message}',
                excludeSemantics: true,
                child: Text(
                  response.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              loading: () => Text(
                'Thinking…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.text.withValues(alpha: 0.5),
                ),
              ),
              // A genuine error here means the fallback path itself broke
              // (see mission_ai_insight_provider.dart's doc comment) — the
              // safest UI response is to disappear, not show raw error text.
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
