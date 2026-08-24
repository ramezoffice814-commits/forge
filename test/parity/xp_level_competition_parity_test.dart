// Dart/SQL parity harness expansion (Roadmap Item 13B step 13). Extends
// the single fixture in xp_reward_parity_test.dart across difficulty
// tiers, streak, recovery, repetition, the daily cap, level boundaries,
// and several competitive-score scenarios — every expected value below
// was independently obtained by calling the real, deployed
// forge_calculate_xp_reward / forge_level_for_xp /
// forge_calculate_competition_score functions directly against the real
// `forge-staging` Postgres during this pass (Roadmap Item 13B), not
// hand-derived only. This file pins the Dart side to those exact
// staging-observed values — a mechanical, not eyeballed, comparison.
//
// Season best-N-of-M aggregation and promotion/demotion (normal, rookie-
// protected, floor, ceiling, tie) are NOT duplicated here: they're already
// staging-verified end-to-end via
// supabase/tests/011_week_finalization.sql and
// supabase/tests/012_season_finalization_and_privacy.sql (re-run against
// real staging Postgres this same pass — see the Item 13B report), and
// unlike XP/competition-score there is no equivalent pure-function,
// no-seed-data-needed Dart counterpart to cross-check against — the
// ranking/aggregation logic lives entirely server-side by design (spec
// section 15/16: the client never computes rank).
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/domain/entities/competitive_completion_summary.dart';
import 'package:forge/features/competition/domain/enums/completion_quality.dart';
import 'package:forge/features/competition/domain/enums/completion_validation_state.dart';
import 'package:forge/features/competition/domain/enums/competition_integrity_state.dart';
import 'package:forge/features/competition/domain/enums/reward_authority_state.dart';
import 'package:forge/features/competition/domain/policies/forge_competitive_score_policy.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/progression/data/catalog/level_catalog.dart';
import 'package:forge/features/progression/domain/entities/completed_mission_summary.dart';
import 'package:forge/features/progression/domain/entities/mission_history_snapshot.dart';
import 'package:forge/features/progression/domain/entities/xp_reward_evaluation.dart';
import 'package:forge/features/progression/domain/policies/level_policy.dart';
import 'package:forge/features/progression/domain/policies/xp_calculation_policy.dart';

MissionHistorySnapshot _snapshot({
  int currentStreakDays = 0,
  Map<String, int> completionsByDefinitionId = const {},
}) => MissionHistorySnapshot(
  totalCompletions: 0,
  completionsByCategory: const {},
  completionsByDefinitionId: completionsByDefinitionId,
  categoriesTried: const {},
  currentStreakDays: currentStreakDays,
  longestStreakDays: currentStreakDays,
  daysSinceLastCompletion: -1,
  advancedOrChallengingCompletions: 0,
  recoveryCompletions: 0,
  justReturnedFromInactivity: false,
);

CompletedMissionSummary _mission({
  required MissionDifficultyLevel difficulty,
  int baseXpHint = 12,
  bool recovery = false,
}) => CompletedMissionSummary(
  missionInstanceId: 'parity-fixture',
  definitionId: 'parity-fixture-def',
  userId: 'parity-fixture-user',
  category: MissionCategory.fitness,
  difficulty: difficulty,
  baseXpHint: baseXpHint,
  resolvedDurationMinutes: 10,
  recoveryMission: recovery,
  completedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('XP formula parity — every expected value observed from real '
      'staging forge_calculate_xp_reward this pass', () {
    final cases = <String, ({int expected, XpRewardEvaluation Function() run})>{
      'restorative, base 10, no history': (
        expected: 6,
        run: () => XpCalculationPolicy.evaluate(
          summary: _mission(
            difficulty: MissionDifficultyLevel.restorative,
            baseXpHint: 10,
          ),
          snapshot: const MissionHistorySnapshot.empty(),
        ),
      ),
      'moderate, base 20, no history': (
        expected: 26,
        run: () => XpCalculationPolicy.evaluate(
          summary: _mission(
            difficulty: MissionDifficultyLevel.moderate,
            baseXpHint: 20,
          ),
          snapshot: const MissionHistorySnapshot.empty(),
        ),
      ),
      'challenging, base 15, no history': (
        expected: 24,
        run: () => XpCalculationPolicy.evaluate(
          summary: _mission(
            difficulty: MissionDifficultyLevel.challenging,
            baseXpHint: 15,
          ),
          snapshot: const MissionHistorySnapshot.empty(),
        ),
      ),
      'advanced, base 25, no history': (
        expected: 50,
        run: () => XpCalculationPolicy.evaluate(
          summary: _mission(
            difficulty: MissionDifficultyLevel.advanced,
            baseXpHint: 25,
          ),
          snapshot: const MissionHistorySnapshot.empty(),
        ),
      ),
      'easy, base 12, 10-day streak': (
        expected: 32,
        run: () => XpCalculationPolicy.evaluate(
          summary: _mission(difficulty: MissionDifficultyLevel.easy),
          snapshot: _snapshot(currentStreakDays: 10),
        ),
      ),
      'easy, base 12, 30-day streak (bonus capped at 20)': (
        expected: 32,
        run: () => XpCalculationPolicy.evaluate(
          summary: _mission(difficulty: MissionDifficultyLevel.easy),
          snapshot: _snapshot(currentStreakDays: 30),
        ),
      ),
      'easy, base 12, recovery mission': (
        expected: 22,
        run: () => XpCalculationPolicy.evaluate(
          summary: _mission(
            difficulty: MissionDifficultyLevel.easy,
            recovery: true,
          ),
          snapshot: const MissionHistorySnapshot.empty(),
        ),
      ),
      'easy, base 12, repeated once recently': (
        expected: 8,
        run: () => XpCalculationPolicy.evaluate(
          summary: _mission(difficulty: MissionDifficultyLevel.easy),
          snapshot: _snapshot(
            completionsByDefinitionId: {'parity-fixture-def': 1},
          ),
        ),
      ),
      'easy, base 12, repeated three times recently': (
        expected: 5,
        run: () => XpCalculationPolicy.evaluate(
          summary: _mission(difficulty: MissionDifficultyLevel.easy),
          snapshot: _snapshot(
            completionsByDefinitionId: {'parity-fixture-def': 3},
          ),
        ),
      ),
      'easy, base 12, 295 XP already earned today (5 remaining)': (
        expected: 5,
        run: () => XpCalculationPolicy.evaluate(
          summary: _mission(difficulty: MissionDifficultyLevel.easy),
          snapshot: const MissionHistorySnapshot.empty(),
          xpAlreadyEarnedToday: 295,
        ),
      ),
      'easy, base 12, daily cap already exhausted': (
        expected: 0,
        run: () => XpCalculationPolicy.evaluate(
          summary: _mission(difficulty: MissionDifficultyLevel.easy),
          snapshot: const MissionHistorySnapshot.empty(),
          xpAlreadyEarnedToday: 300,
        ),
      ),
    };

    cases.forEach((description, fixture) {
      test(description, () {
        expect(fixture.run().finalXpPreview, fixture.expected);
      });
    });
  });

  group('Level-boundary parity — every value observed from real staging '
      'forge_level_for_xp this pass', () {
    final catalog = LevelCatalog.build();
    final cases = <int, int>{
      0: 1,
      49: 1,
      50: 2,
      149: 2,
      150: 3,
      2249: 9,
      2250: 10,
      21750: 30,
      999999: 30,
    };

    cases.forEach((xp, expectedLevel) {
      test('$xp total XP resolves to level $expectedLevel', () {
        expect(LevelPolicy.levelFor(xp, catalog).levelNumber, expectedLevel);
      });
    });
  });

  group('Competitive score parity — every expected value observed from '
      'real staging forge_calculate_competition_score this pass', () {
    CompetitiveCompletionSummary summary({
      required MissionDifficultyLevel difficulty,
      bool recovery = false,
      CompletionQuality quality = CompletionQuality.standard,
      CompetitionIntegrityState integrity = CompetitionIntegrityState.clean,
      int repeated = 0,
    }) => CompetitiveCompletionSummary(
      missionInstanceId: 'parity-fixture',
      userId: 'parity-fixture-user',
      completedAt: DateTime.utc(2026, 1, 1),
      category: MissionCategory.fitness,
      difficulty: difficulty,
      provisionalXp: 0,
      recoveryMission: recovery,
      repeatedMissionCount: repeated,
      completionQuality: quality,
      validationState: CompletionValidationState.valid,
      eventIntegrityState: integrity,
      rewardAuthorityState: RewardAuthorityState.localPreviewOnly,
    );

    test('moderate, standard quality, no repeat/recovery, clean -> 10.0', () {
      final result = ForgeCompetitiveScorePolicy.evaluate(
        summary: summary(difficulty: MissionDifficultyLevel.moderate),
        // priorCompletionsInCategoryThisWeek: 1 (not 0) keeps the
        // diversity factor at exactly 1.0, matching the SQL fixture's
        // diversityFactor input directly rather than deriving 1.1's "new
        // category" bonus.
        priorCompletionsInCategoryThisWeek: 1,
      );
      expect(result.finalScorePreview, closeTo(10.0, 0.0001));
    });

    test('challenging, high quality, recovery mission, clean -> 7.475', () {
      final result = ForgeCompetitiveScorePolicy.evaluate(
        summary: summary(
          difficulty: MissionDifficultyLevel.challenging,
          recovery: true,
          quality: CompletionQuality.high,
        ),
        priorCompletionsInCategoryThisWeek: 1,
      );
      expect(result.finalScorePreview, closeTo(7.475, 0.0001));
    });

    test('advanced, standard quality, integrity warning -> 8.0', () {
      final result = ForgeCompetitiveScorePolicy.evaluate(
        summary: summary(
          difficulty: MissionDifficultyLevel.advanced,
          integrity: CompetitionIntegrityState.warning,
        ),
        priorCompletionsInCategoryThisWeek: 1,
      );
      expect(result.finalScorePreview, closeTo(8.0, 0.0001));
    });

    test('moderate, excluded integrity state -> 0 (never a reduced '
        'positive number)', () {
      final result = ForgeCompetitiveScorePolicy.evaluate(
        summary: summary(
          difficulty: MissionDifficultyLevel.moderate,
          integrity: CompetitionIntegrityState.excluded,
        ),
        priorCompletionsInCategoryThisWeek: 1,
      );
      expect(result.finalScorePreview, 0);
    });
  });
}
