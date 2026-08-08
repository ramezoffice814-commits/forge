import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/domain/entities/league_definition.dart';
import 'package:forge/features/competition/domain/entities/weekly_competition_score.dart';
import 'package:forge/features/competition/domain/enums/completion_quality.dart';
import 'package:forge/features/competition/domain/enums/league_tier.dart';
import 'package:forge/features/competition/domain/policies/competition_scoring_constants.dart';
import 'package:forge/features/competition/domain/policies/forge_competitive_score_policy.dart';
import 'package:forge/features/competition/domain/services/competition_ranking_engine.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';

import '../../../support/competition_test_helpers.dart';

const _league = LeagueDefinition(
  id: 'league-iron',
  name: 'Iron',
  tier: LeagueTier.iron,
  minPlacementRating: 400,
  maxGroupSize: 25,
  promotionCount: 3,
  demotionCount: 3,
  protectedPlacementDays: 7,
  visualTier: 1,
  active: true,
);

const _allLeagues = [
  LeagueDefinition(
    id: 'league-ember',
    name: 'Ember',
    tier: LeagueTier.ember,
    minPlacementRating: 0,
    maxGroupSize: 25,
    promotionCount: 3,
    demotionCount: 0,
    protectedPlacementDays: 7,
    visualTier: 0,
    active: true,
  ),
  _league,
  LeagueDefinition(
    id: 'league-mythic',
    name: 'Mythic',
    tier: LeagueTier.mythic,
    minPlacementRating: 3600,
    maxGroupSize: 25,
    promotionCount: 0,
    demotionCount: 3,
    protectedPlacementDays: 7,
    visualTier: 5,
    active: true,
  ),
];

void main() {
  final now = DateTime.utc(2026, 8, 10);

  test('final per-mission score never exceeds the per-mission cap, across a '
      'wide input sweep', () {
    for (final difficulty in MissionDifficultyLevel.values) {
      for (final quality in CompletionQuality.values) {
        for (final recovery in [true, false]) {
          for (final repeated in [0, 1, 5, 20, 100]) {
            for (final priorInCategory in [0, 5, 20]) {
              final result = ForgeCompetitiveScorePolicy.evaluate(
                summary: testCompetitiveSummary(
                  completedAt: now,
                  difficulty: difficulty,
                  completionQuality: quality,
                  recoveryMission: recovery,
                  repeatedMissionCount: repeated,
                ),
                priorCompletionsInCategoryThisWeek: priorInCategory,
              );
              expect(
                result.finalScorePreview,
                lessThanOrEqualTo(
                  CompetitionScoringConstants.maxScorePerMission,
                ),
              );
              expect(result.finalScorePreview, greaterThanOrEqualTo(0));
            }
          }
        }
      }
    }
  });

  test('a negative score is never possible, regardless of adjustments', () {
    // recovery + heavy repetition + warning integrity stacks every negative
    // adjustment the policy has at once.
    final result = ForgeCompetitiveScorePolicy.evaluate(
      summary: testCompetitiveSummary(
        completedAt: now,
        recoveryMission: true,
        repeatedMissionCount: 500,
      ),
      priorCompletionsInCategoryThisWeek: 500,
    );
    expect(result.finalScorePreview, greaterThanOrEqualTo(0));
  });

  test('lifetime XP never changes weekly rank — ranking participants have no '
      'XP input at all, only WeeklyCompetitionScore.cappedScore', () {
    final participants = [
      CompetitionRankingParticipant(
        userId: 'low-score-veteran',
        displayName: 'Veteran',
        weeklyScore: const WeeklyCompetitionScore(
          userId: 'low-score-veteran',
          seasonId: 'season-1',
          weekNumber: 1,
          rawScore: 10,
          cappedScore: 10,
          completedMissionCount: 1,
          activeDays: 1,
          categoriesUsed: {},
          integrityFlags: {},
          scoreBreakdown: {},
        ),
        averageDifficulty: 1,
        scoreAttainedAt: now,
      ),
      CompetitionRankingParticipant(
        userId: 'high-score-newcomer',
        displayName: 'Newcomer',
        weeklyScore: const WeeklyCompetitionScore(
          userId: 'high-score-newcomer',
          seasonId: 'season-1',
          weekNumber: 1,
          rawScore: 200,
          cappedScore: 200,
          completedMissionCount: 5,
          activeDays: 5,
          categoriesUsed: {},
          integrityFlags: {},
          scoreBreakdown: {},
        ),
        averageDifficulty: 3,
        scoreAttainedAt: now,
      ),
    ];

    final result = CompetitionRankingEngine.rank(
      participants: participants,
      league: _league,
      allLeagues: _allLeagues,
    );

    expect(result.entries.first.userId, 'high-score-newcomer');
  });

  test('recovery contribution never exceeds the recovery cap fraction of '
      'what the same completion would score normally', () {
    for (final difficulty in MissionDifficultyLevel.values) {
      final normal = ForgeCompetitiveScorePolicy.evaluate(
        summary: testCompetitiveSummary(
          completedAt: now,
          difficulty: difficulty,
        ),
        priorCompletionsInCategoryThisWeek: 0,
      );
      final recovery = ForgeCompetitiveScorePolicy.evaluate(
        summary: testCompetitiveSummary(
          completedAt: now,
          difficulty: difficulty,
          recoveryMission: true,
        ),
        priorCompletionsInCategoryThisWeek: 0,
      );
      expect(
        recovery.finalScorePreview,
        lessThanOrEqualTo(
          normal.finalScorePreview *
                  CompetitionScoringConstants.recoveryScoreCapFraction +
              0.001,
        ),
      );
    }
  });

  test(
    'promotion count in the resulting zone never exceeds the league rule',
    () {
      final participants = List.generate(
        12,
        (i) => CompetitionRankingParticipant(
          userId: 'u$i',
          displayName: 'u$i',
          weeklyScore: WeeklyCompetitionScore(
            userId: 'u$i',
            seasonId: 'season-1',
            weekNumber: 1,
            rawScore: (12 - i).toDouble(),
            cappedScore: (12 - i).toDouble(),
            completedMissionCount: 1,
            activeDays: 1,
            categoriesUsed: const {},
            integrityFlags: const {},
            scoreBreakdown: const {},
          ),
          averageDifficulty: 1,
          scoreAttainedAt: now,
        ),
      );

      final result = CompetitionRankingEngine.rank(
        participants: participants,
        league: _league,
        allLeagues: _allLeagues,
      );

      expect(
        result.promotionZoneUserIds.length,
        lessThanOrEqualTo(_league.promotionCount),
      );
      expect(
        result.demotionZoneUserIds.length,
        lessThanOrEqualTo(_league.demotionCount),
      );
    },
  );

  test(
    'the same participant set always produces the same leaderboard order',
    () {
      final participants = List.generate(
        8,
        (i) => CompetitionRankingParticipant(
          userId: 'u$i',
          displayName: 'u$i',
          weeklyScore: WeeklyCompetitionScore(
            userId: 'u$i',
            seasonId: 'season-1',
            weekNumber: 1,
            rawScore: (i * 7 % 40).toDouble(),
            cappedScore: (i * 7 % 40).toDouble(),
            completedMissionCount: 1,
            activeDays: i % 7,
            categoriesUsed: const {},
            integrityFlags: const {},
            scoreBreakdown: const {},
          ),
          averageDifficulty: (i % 5).toDouble(),
          scoreAttainedAt: now.add(Duration(hours: i)),
        ),
      );

      List<String> rankOrder() => CompetitionRankingEngine.rank(
        participants: participants,
        league: _league,
        allLeagues: _allLeagues,
      ).entries.map((e) => e.userId).toList();

      final first = rankOrder();
      final second = rankOrder();
      final third = rankOrder();
      expect(first, second);
      expect(second, third);
    },
  );

  test('an empty participant set never throws, it just ranks nobody', () {
    expect(
      () => CompetitionRankingEngine.rank(
        participants: const [],
        league: _league,
        allLeagues: _allLeagues,
      ),
      returnsNormally,
    );
    final result = CompetitionRankingEngine.rank(
      participants: const [],
      league: _league,
      allLeagues: _allLeagues,
    );
    expect(result.entries, isEmpty);
  });
}
