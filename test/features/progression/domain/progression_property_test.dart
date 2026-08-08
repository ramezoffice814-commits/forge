import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/progression/data/catalog/level_catalog.dart';
import 'package:forge/features/progression/domain/entities/mission_history_snapshot.dart';
import 'package:forge/features/progression/domain/policies/level_policy.dart';
import 'package:forge/features/progression/domain/policies/xp_calculation_policy.dart';

import '../../../support/progression_test_helpers.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);
  final levels = LevelCatalog.build();

  test('XP preview never exceeds maxXpPerMission, across every difficulty x '
      'category-tier x streak x recovery x repeat-count combination '
      '(deterministic sweep)', () {
    var combinations = 0;
    for (final difficulty in MissionDifficultyLevel.values) {
      for (final priorCategoryCompletions in [0, 5, 15, 30, 100]) {
        for (final streakDays in [0, 3, 7, 30, 365]) {
          for (final recovery in [true, false]) {
            for (final repeatCount in [0, 1, 5, 20]) {
              combinations++;
              final snapshot = MissionHistorySnapshot(
                totalCompletions: priorCategoryCompletions,
                completionsByCategory: {
                  MissionCategory.fitness: priorCategoryCompletions,
                },
                completionsByDefinitionId: {'def-1': repeatCount},
                categoriesTried: const {MissionCategory.fitness},
                currentStreakDays: streakDays,
                longestStreakDays: streakDays,
                daysSinceLastCompletion: 0,
                advancedOrChallengingCompletions: 0,
                recoveryCompletions: 0,
                justReturnedFromInactivity: false,
              );
              final result = XpCalculationPolicy.evaluate(
                summary: testCompletedSummary(
                  definitionId: 'def-1',
                  difficulty: difficulty,
                  baseXpHint: 9999, // deliberately huge to stress the caps
                  recoveryMission: recovery,
                  completedAt: now,
                ),
                snapshot: snapshot,
              );
              expect(
                result.finalXpPreview,
                lessThanOrEqualTo(XpCalculationPolicy.maxXpPerMission),
                reason:
                    '$difficulty/$priorCategoryCompletions/$streakDays/'
                    '$recovery/$repeatCount',
              );
              expect(result.finalXpPreview, greaterThanOrEqualTo(0));
            }
          }
        }
      }
    }
    expect(combinations, greaterThan(100));
  });

  test('identical (summary, snapshot) inputs always produce identical '
      'output across the same sweep', () {
    for (final difficulty in MissionDifficultyLevel.values) {
      final snapshot = MissionHistorySnapshot(
        totalCompletions: 5,
        completionsByCategory: const {},
        completionsByDefinitionId: const {},
        categoriesTried: const {},
        currentStreakDays: 4,
        longestStreakDays: 4,
        daysSinceLastCompletion: 0,
        advancedOrChallengingCompletions: 0,
        recoveryCompletions: 0,
        justReturnedFromInactivity: false,
      );
      final summary = testCompletedSummary(
        difficulty: difficulty,
        completedAt: now,
      );
      final a = XpCalculationPolicy.evaluate(
        summary: summary,
        snapshot: snapshot,
      );
      final b = XpCalculationPolicy.evaluate(
        summary: summary,
        snapshot: snapshot,
      );
      expect(a.finalXpPreview, b.finalXpPreview);
    }
  });

  test('level never decreases as XP monotonically increases', () {
    var previousLevel = 1;
    for (var xp = 0; xp <= 50000; xp += 137) {
      final level = LevelPolicy.levelFor(xp, levels).levelNumber;
      expect(level, greaterThanOrEqualTo(previousLevel));
      previousLevel = level;
    }
  });
}
