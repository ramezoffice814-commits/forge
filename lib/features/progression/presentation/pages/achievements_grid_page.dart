import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_error_state.dart';
import '../../../../shared/widgets/forge_loading_state.dart';
import '../../../../shared/widgets/forge_scaffold.dart';
import '../../domain/entities/achievement_progress.dart';
import '../providers/progression_controller.dart';
import '../providers/progression_state.dart';
import '../widgets/achievement_card.dart';

/// The Awards tab's real content: the full locked/progressing/unlocked
/// achievements grid. Unlocked ones sort first so the page opens on what's
/// already been earned.
class AchievementsGridPage extends ConsumerWidget {
  const AchievementsGridPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(progressionControllerProvider);
    return ForgeScaffold(
      appBarTitle: 'Awards',
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
        message: 'Loading your achievements…',
      ),
      ProgressionError(:final message) => ForgeErrorState(message: message),
      ProgressionReady ready => _Grid(
        achievements: [
          ...ready.aggregate.achievements.alreadyUnlocked,
          ...ready.aggregate.achievements.newlyUnlocked,
          ...ready.aggregate.achievements.progressUpdates,
        ],
      ),
    };
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.achievements});

  final List<AchievementProgress> achievements;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return ListView.separated(
      padding: EdgeInsets.all(tokens.spacing.space4),
      itemCount: achievements.length,
      separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.space2),
      itemBuilder: (context, index) =>
          AchievementCard(progress: achievements[index]),
    );
  }
}
