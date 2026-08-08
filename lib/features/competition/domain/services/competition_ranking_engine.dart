import 'package:flutter/foundation.dart';

import '../entities/leaderboard_entry.dart';
import '../entities/league_definition.dart';
import '../entities/weekly_competition_score.dart';
import '../enums/promotion_status.dart';
import '../policies/league_movement_policy.dart';
import 'competition_ranking_result.dart';

/// One participant's ranking-relevant inputs — never more than the ranking
/// engine actually needs (privacy: no raw completion history, no habits).
@immutable
class CompetitionRankingParticipant {
  const CompetitionRankingParticipant({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.weeklyScore,
    required this.averageDifficulty,
    required this.scoreAttainedAt,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final WeeklyCompetitionScore weeklyScore;

  /// Numeric average of this week's mission difficulties — the tie-break
  /// input from `LeagueMovementPolicy`'s documented order.
  final double averageDifficulty;

  /// When this score was last updated — the tie-break's "earlier
  /// attainment timestamp" input.
  final DateTime scoreAttainedAt;
}

/// Deterministic: the same [participants] input always produces the same
/// ranking (spec section 25) — no `Random()`, no wall-clock dependency
/// beyond what's passed in explicitly. Lifetime XP is never an input here
/// at all, so it structurally cannot affect order.
abstract final class CompetitionRankingEngine {
  static CompetitionRankingResult rank({
    required List<CompetitionRankingParticipant> participants,
    required LeagueDefinition league,
    required List<LeagueDefinition> allLeagues,
    Set<String> protectedUserIds = const {},
  }) {
    final sorted = [...participants]
      ..sort(
        (a, b) => LeagueMovementPolicy.compareForRanking(
          scoreA: a.weeklyScore.cappedScore,
          scoreB: b.weeklyScore.cappedScore,
          activeDaysA: a.weeklyScore.activeDays,
          activeDaysB: b.weeklyScore.activeDays,
          avgDifficultyA: a.averageDifficulty,
          avgDifficultyB: b.averageDifficulty,
          attainedAtA: a.scoreAttainedAt,
          attainedAtB: b.scoreAttainedAt,
          userIdA: a.userId,
          userIdB: b.userId,
        ),
      );

    final tieBreakNotes = <String, String>{};
    for (var i = 1; i < sorted.length; i++) {
      final previous = sorted[i - 1];
      final current = sorted[i];
      if (previous.weeklyScore.cappedScore == current.weeklyScore.cappedScore) {
        tieBreakNotes[current.userId] =
            'Tied on score with ${previous.displayName} — ranked by active '
            'days, average difficulty, then earliest attainment';
      }
    }

    final provisionalEntries = <LeaderboardEntry>[
      for (var i = 0; i < sorted.length; i++)
        LeaderboardEntry(
          userId: sorted[i].userId,
          displayName: sorted[i].displayName,
          avatarUrl: sorted[i].avatarUrl,
          league: league.name,
          rank: i + 1,
          weeklyScore: sorted[i].weeklyScore.cappedScore,
          activeDays: sorted[i].weeklyScore.activeDays,
          promotionStatus: PromotionStatus.safeZone,
        ),
    ];

    final movements = LeagueMovementPolicy.evaluate(
      rankedEntries: provisionalEntries,
      league: league,
      allLeagues: allLeagues,
      protectedUserIds: protectedUserIds,
    );
    final zoneByUser = {for (final m in movements) m.userId: m.zone};

    final finalEntries = [
      for (final entry in provisionalEntries)
        LeaderboardEntry(
          userId: entry.userId,
          displayName: entry.displayName,
          avatarUrl: entry.avatarUrl,
          league: entry.league,
          rank: entry.rank,
          weeklyScore: entry.weeklyScore,
          activeDays: entry.activeDays,
          promotionStatus: zoneByUser[entry.userId] ?? PromotionStatus.safeZone,
        ),
    ];

    return CompetitionRankingResult(
      entries: finalEntries,
      promotionZoneUserIds: {
        for (final e in finalEntries)
          if (e.promotionStatus == PromotionStatus.promotionZone) e.userId,
      },
      demotionZoneUserIds: {
        for (final e in finalEntries)
          if (e.promotionStatus == PromotionStatus.demotionZone) e.userId,
      },
      tieBreakNotes: tieBreakNotes,
    );
  }
}
