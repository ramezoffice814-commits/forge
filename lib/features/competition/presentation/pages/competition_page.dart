import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_card.dart';
import '../../../../shared/widgets/forge_error_state.dart';
import '../../../../shared/widgets/forge_loading_state.dart';
import '../../../../shared/widgets/forge_scaffold.dart';
import '../providers/competition_controller.dart';
import '../providers/competition_providers.dart';
import '../providers/competition_state.dart';
import '../widgets/fairness_explanation_sheet.dart';
import '../widgets/hall_of_fame_list.dart';
import '../widgets/league_leaderboard_list.dart';
import '../widgets/league_movement_preview_card.dart';
import '../widgets/rookie_placement_banner.dart';
import '../widgets/season_progress_card.dart';

/// The Rank tab's real content — My League, Season, and Hall of Fame.
/// Every number comes from `CompetitionController`; nothing here computes
/// a score, a rank, or a movement decision itself. A Friends tab is
/// deliberately absent rather than a disabled placeholder — the module
/// only defines the interface for it (spec section 34), no UI yet.
class CompetitionPage extends ConsumerWidget {
  const CompetitionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(competitionControllerProvider);
    return DefaultTabController(
      length: 3,
      child: ForgeScaffold(
        appBarTitle: 'Rank',
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'How ranking works',
            onPressed: () => FairnessExplanationSheet.show(context),
          ),
        ],
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'My League'),
                Tab(text: 'Season'),
                Tab(text: 'Hall of Fame'),
              ],
            ),
            Expanded(child: _Body(state: state)),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final CompetitionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (state) {
      CompetitionLoading() => const ForgeLoadingState(
        message: 'Loading your league standing…',
      ),
      CompetitionError(:final message) => ForgeErrorState(message: message),
      CompetitionReady ready => TabBarView(
        children: [
          _MyLeagueTab(state: ready),
          _SeasonTab(state: ready),
          _HallOfFameTab(state: ready),
        ],
      ),
    };
  }
}

class _MyLeagueTab extends ConsumerWidget {
  const _MyLeagueTab({required this.state});

  final CompetitionReady state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final current = state.current;
    final userId = ref.watch(currentCompetitionUserIdProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (current.rookieStatus.isRookie) ...[
            RookiePlacementBanner(status: current.rookieStatus),
            SizedBox(height: tokens.spacing.space3),
          ],
          LeagueMovementPreviewCard(preview: current.movementPreview),
          SizedBox(height: tokens.spacing.space3),
          ForgeCard(
            elevation: ForgeCardElevation.md,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${current.league.name} League',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${current.weeklyScore.cappedScore.toStringAsFixed(0)} pts '
                    '(preview)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.space2),
              LeagueLeaderboardList(
                ranking: current.ranking,
                currentUserId: userId,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeasonTab extends StatelessWidget {
  const _SeasonTab({required this.state});

  final CompetitionReady state;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spacing.space4),
      child: SeasonProgressCard(snapshot: state.seasonProgress),
    );
  }
}

class _HallOfFameTab extends StatelessWidget {
  const _HallOfFameTab({required this.state});

  final CompetitionReady state;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spacing.space4),
      child: HallOfFameList(records: state.hallOfFame),
    );
  }
}
