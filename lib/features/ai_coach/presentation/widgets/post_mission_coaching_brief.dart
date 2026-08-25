import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/enums/ai_privacy_level.dart';
import '../providers/ai_coach_providers.dart';
import '../providers/post_mission_coaching_provider.dart';

/// Shown once on the post-completion screen, after the deterministic
/// reward summary (XP/level/achievements) — never before or in place of
/// it. Purely additive commentary; nothing here can be mistaken for the
/// authoritative result, which the caller renders separately.
class PostMissionCoachingBrief extends ConsumerWidget {
  const PostMissionCoachingBrief({
    super.key,
    required this.displayName,
    required this.missionTitle,
    required this.missionCategory,
    required this.consistencySummary,
  });

  final String displayName;
  final String missionTitle;
  final String missionCategory;
  final String consistencySummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacyLevel = ref.watch(aiPrivacyLevelProvider);
    if (privacyLevel == AiPrivacyLevel.disabled) return const SizedBox.shrink();

    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final brief = ref.watch(
      postMissionCoachingProvider(
        PostMissionCoachingParams(
          displayName: displayName,
          missionTitle: missionTitle,
          missionCategory: missionCategory,
          consistencySummary: consistencySummary,
        ),
      ),
    );

    return brief.when(
      data: (response) => Padding(
        padding: EdgeInsets.only(top: tokens.spacing.space2),
        child: Text(
          response.message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
