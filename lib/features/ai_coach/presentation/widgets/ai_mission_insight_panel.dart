import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/enums/ai_privacy_level.dart';
import '../providers/ai_coach_providers.dart';
import '../providers/mission_ai_insight_provider.dart';
import 'suggested_action_bar.dart';

/// AI-generated mission insight (Roadmap Item 14B) — additive and
/// visually distinct from the deterministic `MissionExplanationPanel`:
/// this widget never replaces it, only sits alongside it. Renders
/// nothing (not just empty) when AI is disabled, there is no
/// authoritative mission yet, or the underlying request/fallback
/// genuinely errors — never a loading spinner that blocks the rest of
/// the card, never an error message a user would need to act on.
class AiMissionInsightPanel extends ConsumerWidget {
  const AiMissionInsightPanel({super.key, required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacyLevel = ref.watch(aiPrivacyLevelProvider);
    if (privacyLevel == AiPrivacyLevel.disabled) return const SizedBox.shrink();

    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final insight = ref.watch(missionAiInsightProvider(displayName));

    return insight.when(
      data: (response) {
        if (response == null) return const SizedBox.shrink();
        return Container(
          padding: EdgeInsets.all(tokens.spacing.space2),
          decoration: BoxDecoration(
            color: tokens.accent.withValues(alpha: 0.08),
            borderRadius: tokens.radius.mdRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: tokens.accent),
                  SizedBox(width: tokens.spacing.space1),
                  Expanded(
                    child: Semantics(
                      label: 'AI coach insight: ${response.message}',
                      excludeSemantics: true,
                      child: Text(
                        response.message,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
              SuggestedActionBar(actions: response.suggestedActions),
            ],
          ),
        );
      },
      // Bounded, non-blocking: the rest of the card already rendered —
      // this is purely additive content still resolving underneath it,
      // never a reason to hold up anything else on the page.
      loading: () => const SizedBox.shrink(),
      // A genuine error here means the fallback path itself broke (see
      // mission_ai_insight_provider.dart's doc comment) — the safest UI
      // response is to disappear, not show raw error text.
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
