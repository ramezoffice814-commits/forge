import '../entities/leaderboard_entry.dart';
import '../entities/league_definition.dart';
import '../entities/league_movement.dart';
import '../policies/league_movement_policy.dart';
import '../services/competition_ranking_result.dart';

/// Turns a ranking result into the UI-facing [LeagueMovementPreview] for
/// one participant — deliberately worded as a preview, never a promise
/// (spec section 30: "currently in promotion zone," not "you will be
/// promoted").
class EvaluateLeagueMovementUseCase {
  const EvaluateLeagueMovementUseCase();

  LeagueMovementPreview previewFor({
    required String userId,
    required CompetitionRankingResult ranking,
    required int promotionCount,
    required int demotionCount,
  }) {
    final entries = ranking.entries;
    final index = entries.indexWhere((e) => e.userId == userId);
    if (index == -1) {
      throw ArgumentError('userId not present in ranking result: $userId');
    }
    final entry = entries[index];
    final total = entries.length;

    final pointsToNextRank = index == 0
        ? 0.0
        : entries[index - 1].weeklyScore - entry.weeklyScore;

    return LeagueMovementPreview(
      promotionThresholdRank: promotionCount,
      demotionThresholdRank: total - demotionCount + 1,
      currentRank: entry.rank,
      zone: entry.promotionStatus,
      pointsToNextRank: pointsToNextRank,
    );
  }

  List<LeagueMovementEvaluation> call({
    required List<LeaderboardEntry> rankedEntries,
    required LeagueDefinition league,
    required List<LeagueDefinition> allLeagues,
    Set<String> protectedUserIds = const {},
  }) {
    return LeagueMovementPolicy.evaluate(
      rankedEntries: rankedEntries,
      league: league,
      allLeagues: allLeagues,
      protectedUserIds: protectedUserIds,
    );
  }
}
