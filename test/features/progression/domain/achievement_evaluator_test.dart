import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/progression/domain/entities/achievement_definition.dart';
import 'package:forge/features/progression/domain/entities/achievement_progress.dart';
import 'package:forge/features/progression/domain/entities/mission_history_snapshot.dart';
import 'package:forge/features/progression/domain/services/achievement_evaluator.dart';

void main() {
  const catalog = [
    AchievementDefinition(
      id: 'first',
      name: 'First',
      description: 'First mission',
      category: AchievementCategory.consistency,
      criteria: TotalCompletionsCriteria(1),
      rarity: AchievementRarity.common,
      iconId: 'first',
    ),
    AchievementDefinition(
      id: 'ten_coding',
      name: 'Ten Coding',
      description: '10 coding missions',
      category: AchievementCategory.skill,
      criteria: CategoryCompletionsCriteria(
        category: MissionCategory.coding,
        target: 10,
      ),
      rarity: AchievementRarity.uncommon,
      iconId: 'ten_coding',
    ),
    AchievementDefinition(
      id: 'inactive_one',
      name: 'Inactive',
      description: 'Never shown',
      category: AchievementCategory.mastery,
      criteria: TotalCompletionsCriteria(1),
      rarity: AchievementRarity.common,
      iconId: 'inactive_one',
      active: false,
    ),
  ];

  MissionHistorySnapshot snapshotWith({
    int total = 0,
    Map<MissionCategory, int> byCategory = const {},
  }) {
    return MissionHistorySnapshot(
      totalCompletions: total,
      completionsByCategory: byCategory,
      completionsByDefinitionId: const {},
      categoriesTried: byCategory.keys.toSet(),
      currentStreakDays: 0,
      longestStreakDays: 0,
      daysSinceLastCompletion: 0,
      advancedOrChallengingCompletions: 0,
      recoveryCompletions: 0,
      justReturnedFromInactivity: false,
    );
  }

  test('an achievement whose criteria is met and not yet unlocked is '
      'newly unlocked', () {
    final result = AchievementEvaluator.evaluate(
      snapshot: snapshotWith(total: 1),
      unlockedIds: const {},
      catalog: catalog,
    );
    expect(result.newlyUnlocked.map((a) => a.definition.id), contains('first'));
    expect(result.newlyUnlocked.first.status, AchievementStatus.unlocked);
  });

  test('an already-unlocked achievement is never re-reported as newly '
      'unlocked (no duplicate unlocks)', () {
    final result = AchievementEvaluator.evaluate(
      snapshot: snapshotWith(total: 5),
      unlockedIds: const {'first'},
      catalog: catalog,
    );
    expect(result.newlyUnlocked, isEmpty);
    expect(
      result.alreadyUnlocked.map((a) => a.definition.id),
      contains('first'),
    );
  });

  test('progress is reported for a not-yet-met criterion', () {
    final result = AchievementEvaluator.evaluate(
      snapshot: snapshotWith(total: 4, byCategory: {MissionCategory.coding: 3}),
      unlockedIds: const {'first'},
      catalog: catalog,
    );
    final tenCoding = result.progressUpdates.firstWhere(
      (a) => a.definition.id == 'ten_coding',
    );
    expect(tenCoding.current, 3);
    expect(tenCoding.target, 10);
    expect(tenCoding.status, AchievementStatus.progressing);
  });

  test('zero progress on an unmet criterion is reported as locked, not '
      'progressing', () {
    final result = AchievementEvaluator.evaluate(
      snapshot: snapshotWith(total: 0),
      unlockedIds: const {},
      catalog: catalog,
    );
    final tenCoding = result.progressUpdates.firstWhere(
      (a) => a.definition.id == 'ten_coding',
    );
    expect(tenCoding.status, AchievementStatus.locked);
  });

  test('an inactive achievement is never evaluated at all', () {
    final result = AchievementEvaluator.evaluate(
      snapshot: snapshotWith(total: 5),
      unlockedIds: const {},
      catalog: catalog,
    );
    final ids = [
      ...result.newlyUnlocked,
      ...result.alreadyUnlocked,
      ...result.progressUpdates,
    ].map((a) => a.definition.id);
    expect(ids, isNot(contains('inactive_one')));
  });

  test('evaluating twice with the same snapshot and unlocked set is '
      'deterministic', () {
    final a = AchievementEvaluator.evaluate(
      snapshot: snapshotWith(total: 1),
      unlockedIds: const {},
      catalog: catalog,
    );
    final b = AchievementEvaluator.evaluate(
      snapshot: snapshotWith(total: 1),
      unlockedIds: const {},
      catalog: catalog,
    );
    expect(
      a.newlyUnlocked.map((x) => x.definition.id),
      b.newlyUnlocked.map((x) => x.definition.id),
    );
  });
}
