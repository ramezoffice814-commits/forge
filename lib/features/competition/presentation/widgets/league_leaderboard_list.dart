import 'package:flutter/material.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/services/competition_ranking_result.dart';
import 'leaderboard_entry_tile.dart';

/// The full ranked list for one league group — deliberately a plain
/// [Column] rather than a lazy [ListView]: group sizes are capped at
/// `LeagueDefinition.maxGroupSize` (25 in this catalog), small enough that
/// virtualization would be overhead, not a benefit.
class LeagueLeaderboardList extends StatelessWidget {
  const LeagueLeaderboardList({
    super.key,
    required this.ranking,
    required this.currentUserId,
  });

  final CompetitionRankingResult ranking;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in ranking.entries) ...[
          LeaderboardEntryTile(
            entry: entry,
            isCurrentUser: entry.userId == currentUserId,
          ),
          if (entry != ranking.entries.last)
            Divider(height: tokens.spacing.space2, color: tokens.divider),
        ],
      ],
    );
  }
}
