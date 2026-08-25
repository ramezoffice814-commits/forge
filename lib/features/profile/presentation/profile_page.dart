import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/forge_tokens.dart';
import '../../../shared/widgets/forge_button.dart';
import '../../../shared/widgets/forge_card.dart';
import '../../../shared/widgets/forge_loading_state.dart';
import '../../../shared/widgets/forge_scaffold.dart';
import '../../ai_coach/presentation/widgets/ai_privacy_settings_tile.dart';
import '../../competition/presentation/widgets/profile_competition_summary.dart';
import '../../progression/presentation/providers/progression_controller.dart';
import '../../progression/presentation/providers/progression_state.dart';
import '../../progression/presentation/widgets/level_badge.dart';

/// Profile tab root. Shows only the progression summary this phase adds
/// (level, title, achievement count) — full profile editing (avatar,
/// settings list) lands in a later roadmap item.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final state = ref.watch(progressionControllerProvider);

    return ForgeScaffold(
      appBarTitle: 'Profile',
      body: switch (state) {
        ProgressionReady ready => SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ForgeCard(
                elevation: ForgeCardElevation.md,
                children: [
                  LevelBadge(
                    levelNumber: ready.aggregate.profile.currentLevel,
                    levelTitle: ready.aggregate.currentLevelDefinition.title,
                    progressToNextLevel: ready.aggregate.levelProgress,
                  ),
                  SizedBox(height: tokens.spacing.space3),
                  Text(
                    ready.aggregate.profile.currentTitle.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: tokens.spacing.space1),
                  Text(
                    '${ready.aggregate.profile.unlockedAchievementIds.length} '
                    'achievement(s) unlocked',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.text.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.space3),
              const ForgeCard(
                elevation: ForgeCardElevation.md,
                children: [ProfileCompetitionSummary()],
              ),
              SizedBox(height: tokens.spacing.space3),
              ForgeCard(
                elevation: ForgeCardElevation.md,
                children: [
                  Text('Social', style: Theme.of(context).textTheme.titleSmall),
                  SizedBox(height: tokens.spacing.space1),
                  Text(
                    'Friends, requests, and activity',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.text.withValues(alpha: 0.7),
                    ),
                  ),
                  SizedBox(height: tokens.spacing.space2),
                  ForgeButton(
                    label: 'Open Social',
                    variant: ForgeButtonVariant.secondary,
                    onPressed: () => context.goNamed(AppRouteNames.social),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.space3),
              const ForgeCard(
                elevation: ForgeCardElevation.md,
                children: [AiPrivacySettingsTile()],
              ),
            ],
          ),
        ),
        _ => const ForgeLoadingState(message: 'Loading your profile…'),
      },
    );
  }
}
