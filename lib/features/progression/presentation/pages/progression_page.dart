import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_bottom_navigation_bar.dart';
import '../../../../shared/widgets/forge_button.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../../../shared/widgets/forge_error_state.dart';
import '../../../../shared/widgets/forge_loading_state.dart';
import '../../../../shared/widgets/forge_progress_ring.dart';
import '../../../../shared/widgets/forge_scaffold.dart';
import '../../domain/entities/achievement_progress.dart';
import '../providers/progression_controller.dart';
import '../providers/progression_state.dart';
import '../widgets/achievement_card.dart';
import '../widgets/category_progress_row.dart';
import '../widgets/level_up_celebration.dart';

/// Responsive sizing for the level ring (Mobile Polish Pass 1) — a pure
/// function of the width actually available inside its card, so it's
/// unit-testable without pumping the whole page. The max (180) is the
/// ring's original, already-reasonable fixed size on any normal phone or
/// tablet width — this is a narrow-width safety net (shrink below 180
/// only when the available width is genuinely that tight), not a way to
/// grow the ring bigger everywhere. 140 is a preferred floor, not a hard
/// one: below that (not expected on any real phone once the page's own
/// padding is accounted for), returning the raw [availableWidth]
/// guarantees no overflow rather than clamping up past what's available.
double responsiveLevelRingSize(double availableWidth) {
  const preferredMin = 140.0;
  const preferredMax = 180.0;
  return availableWidth >= preferredMin
      ? availableWidth.clamp(preferredMin, preferredMax)
      : availableWidth;
}

/// The Progress tab's real content — level, XP preview, title, and category
/// growth, plus a short "recent achievements" preview (the full grid lives
/// on the dedicated Awards tab — see `AchievementsGridPage`). Every number
/// comes from `ProgressionController`; nothing here computes XP or
/// evaluates an achievement itself.
class ProgressionPage extends ConsumerWidget {
  const ProgressionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(progressionControllerProvider);
    return ForgeScaffold(
      appBarTitle: 'Progress',
      body: _Body(state: state),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final ProgressionState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ProgressionLoading() => const ForgeLoadingState(
        message: 'Loading your progression…',
      ),
      ProgressionError(:final message) => ForgeErrorState(message: message),
      ProgressionReady ready => _ProgressionContent(state: ready),
    };
  }
}

class _ProgressionContent extends ConsumerWidget {
  const _ProgressionContent({required this.state});

  final ProgressionReady state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final aggregate = state.aggregate;
    final profile = aggregate.profile;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final notifier = ref.read(progressionControllerProvider.notifier);

    final unlocked = [
      ...aggregate.achievements.alreadyUnlocked,
      ...aggregate.achievements.newlyUnlocked,
    ];
    final inProgress = aggregate.achievements.progressUpdates;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.space4,
        tokens.spacing.space4,
        tokens.spacing.space4,
        ForgeBottomNavigationBar.shellContentBottomClearance(tokens),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.lastLevelResult?.justLeveledUp ?? false) ...[
            LevelUpCelebration(
              levelNumber: aggregate.currentLevelDefinition.levelNumber,
              levelTitle: aggregate.currentLevelDefinition.title,
              reducedMotion: reducedMotion,
              onDismiss: notifier.dismissCelebration,
            ),
            SizedBox(height: tokens.spacing.space4),
          ],
          ForgeCard(
            elevation: ForgeCardElevation.md,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label:
                    'Level ${profile.currentLevel}, '
                    '${(aggregate.levelProgress * 100).round()} percent to '
                    'next level',
                // Responsive instead of ForgeProgressRing's fixed 180px
                // default (Mobile Polish Pass 1) — LayoutBuilder reads the
                // actual width available inside this card (already net of
                // the page's own horizontal padding and the card's own
                // internal padding). The max stays 180 — the ring's
                // existing, already-reasonable size on any normal phone
                // or tablet width — so this is a pure narrow-width safety
                // net (shrinks below 180 only when the available width
                // actually is that tight) rather than growing the ring
                // bigger everywhere. 140 is a preferred floor, not a hard
                // one: on a container narrower than that (not expected on
                // any real phone once padding is accounted for), falling
                // back to the raw available width guarantees no overflow
                // rather than clamping up past it.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final ringSize = responsiveLevelRingSize(
                      constraints.maxWidth,
                    );
                    return ForgeProgressRing(
                      progress: aggregate.levelProgress,
                      size: ringSize,
                      strokeWidth: ringSize / 180 * 14,
                      child: ExcludeSemantics(
                        child: Text(
                          '${profile.currentLevel}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: tokens.spacing.space2),
              Text(
                aggregate.currentLevelDefinition.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                aggregate.currentLevelDefinition.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.text.withValues(alpha: 0.7),
                ),
              ),
              SizedBox(height: tokens.spacing.space2),
              Text(
                '${profile.previewTotalXp} XP (preview, not yet confirmed)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.space4),
          ForgeCard(
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Title',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              SizedBox(height: tokens.spacing.space1),
              Text(
                profile.currentTitle.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                profile.currentTitle.unlockReason,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.text.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.space4),
          if (profile.categoryProgress.isNotEmpty)
            ForgeCard(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Category growth',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final progress in profile.categoryProgress.values)
                  CategoryProgressRow(progress: progress),
              ],
            ),
          SizedBox(height: tokens.spacing.space4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Recent achievements (${unlocked.length} unlocked)',
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ForgeButton(
                label: 'View all',
                variant: ForgeButtonVariant.ghost,
                onPressed: () => context.goNamed(AppRouteNames.awards),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.space2),
          _RecentAchievements(
            achievements: [
              ...unlocked.reversed,
              ...inProgress,
            ].take(3).toList(),
          ),
        ],
      ),
    );
  }
}

class _RecentAchievements extends StatelessWidget {
  const _RecentAchievements({required this.achievements});

  final List<AchievementProgress> achievements;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final achievement in achievements) ...[
          AchievementCard(progress: achievement),
          SizedBox(height: tokens.spacing.space2),
        ],
      ],
    );
  }
}
