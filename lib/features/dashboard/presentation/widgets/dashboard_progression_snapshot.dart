import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/forge_tokens.dart';
import '../../../progression/presentation/providers/progression_controller.dart';
import '../../../progression/presentation/providers/progression_state.dart';
import '../../../progression/presentation/widgets/level_badge.dart';
import '../../../progression/presentation/widgets/level_up_celebration.dart';

/// The one small, additive progression touchpoint on the Dashboard (spec
/// section 21: "current level badge, progress to next level, recent
/// achievement" — deliberately nothing more, mission stays the page's main
/// focus). Renders nothing while progression is still loading rather than
/// reserving space or showing a spinner next to the header.
class DashboardProgressionSnapshot extends ConsumerWidget {
  const DashboardProgressionSnapshot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(progressionControllerProvider);
    if (state is! ProgressionReady) return const SizedBox.shrink();

    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final aggregate = state.aggregate;
    final recent = state.recentlyUnlocked;
    final justLeveledUp = state.lastLevelResult?.justLeveledUp ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (justLeveledUp) ...[
          LevelUpCelebration(
            levelNumber: aggregate.currentLevelDefinition.levelNumber,
            levelTitle: aggregate.currentLevelDefinition.title,
            reducedMotion: MediaQuery.of(context).disableAnimations,
            onDismiss: () => ref
                .read(progressionControllerProvider.notifier)
                .dismissCelebration(),
          ),
          SizedBox(height: tokens.spacing.space3),
        ],
        InkWell(
          borderRadius: tokens.radius.mdRadius,
          onTap: () => context.goNamed(AppRouteNames.progress),
          child: Row(
            children: [
              LevelBadge(
                levelNumber: aggregate.profile.currentLevel,
                levelTitle: aggregate.currentLevelDefinition.title,
                progressToNextLevel: aggregate.levelProgress,
                size: 40,
              ),
              if (!justLeveledUp && recent.isNotEmpty) ...[
                SizedBox(width: tokens.spacing.space3),
                Expanded(
                  child: Text(
                    'New: ${recent.first.definition.name}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.accent),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
