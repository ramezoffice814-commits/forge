import '../entities/leaderboard_entry.dart';
import '../entities/league_definition.dart';
import '../entities/league_movement.dart';
import '../enums/league_tier.dart';
import '../enums/promotion_status.dart';

/// Zone/movement decisions from an already-ranked leaderboard — ranking
/// itself (including tie-breaking) is `CompetitionRankingEngine`'s job;
/// this policy only turns a final rank into promotion/safe/demotion and,
/// for promotion/demotion, a target league — honoring floor/ceiling and
/// protection.
abstract final class LeagueMovementPolicy {
  /// [rankedEntries] must already be in final rank order (rank 1 first).
  static List<LeagueMovementEvaluation> evaluate({
    required List<LeaderboardEntry> rankedEntries,
    required LeagueDefinition league,
    required List<LeagueDefinition> allLeagues,
    required Set<String> protectedUserIds,
  }) {
    final total = rankedEntries.length;
    final sortedLeagues = [...allLeagues]
      ..sort((a, b) => a.tier.index.compareTo(b.tier.index));
    final leagueIndex = sortedLeagues.indexWhere((l) => l.id == league.id);

    return rankedEntries.map((entry) {
      final rank = entry.rank;
      final isProtected = protectedUserIds.contains(entry.userId);

      final inPromotionZone =
          league.promotionCount > 0 && rank <= league.promotionCount;
      final inDemotionZone =
          league.demotionCount > 0 && rank > total - league.demotionCount;

      PromotionStatus zone;
      String? targetLeagueId;
      final reasons = <String>[];

      final hasNextTier =
          leagueIndex != -1 && leagueIndex + 1 < sortedLeagues.length;
      final hasPreviousTier = leagueIndex > 0;

      if (inPromotionZone && !league.tier.isCeiling && hasNextTier) {
        zone = PromotionStatus.promotionZone;
        targetLeagueId = sortedLeagues[leagueIndex + 1].id;
        reasons.add('Rank $rank is within the top ${league.promotionCount}');
      } else if (inDemotionZone && !league.tier.isFloor && hasPreviousTier) {
        if (isProtected) {
          zone = PromotionStatus.safeZone;
          reasons.add('Demotion suppressed — protected this period');
        } else {
          zone = PromotionStatus.demotionZone;
          targetLeagueId = sortedLeagues[leagueIndex - 1].id;
          reasons.add(
            'Rank $rank is within the bottom ${league.demotionCount}',
          );
        }
      } else {
        zone = PromotionStatus.safeZone;
        reasons.add('Rank $rank is in the safe zone');
      }

      return LeagueMovementEvaluation(
        userId: entry.userId,
        currentLeagueId: league.id,
        zone: zone,
        targetLeagueId: targetLeagueId,
        rank: rank,
        protected: isProtected,
        reasons: reasons,
        ruleVersion: 1,
      );
    }).toList();
  }

  /// Tie-break order, applied only when two entries have an identical
  /// score: (1) higher score itself — already equal here, so this only
  /// matters when called on the full comparator; (2) more active days; (3)
  /// higher average mission difficulty (passed in as a precomputed
  /// number); (4) earlier attainment timestamp; (5) a deterministic stable
  /// fallback (`userId` lexicographic). Account age is never used.
  static int compareForRanking({
    required double scoreA,
    required double scoreB,
    required int activeDaysA,
    required int activeDaysB,
    required double avgDifficultyA,
    required double avgDifficultyB,
    required DateTime attainedAtA,
    required DateTime attainedAtB,
    required String userIdA,
    required String userIdB,
  }) {
    final byScore = scoreB.compareTo(scoreA);
    if (byScore != 0) return byScore;

    final byActiveDays = activeDaysB.compareTo(activeDaysA);
    if (byActiveDays != 0) return byActiveDays;

    final byDifficulty = avgDifficultyB.compareTo(avgDifficultyA);
    if (byDifficulty != 0) return byDifficulty;

    final byAttainedAt = attainedAtA.compareTo(attainedAtB);
    if (byAttainedAt != 0) return byAttainedAt;

    return userIdA.compareTo(userIdB);
  }
}
