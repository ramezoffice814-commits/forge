import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/progression/domain/entities/mission_history_snapshot.dart';
import 'package:forge/features/progression/domain/policies/xp_calculation_policy.dart';

import '../../../support/progression_test_helpers.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);
  const emptySnapshot = MissionHistorySnapshot.empty();

  test('base XP with no bonuses is base * difficulty multiplier', () {
    final summary = testCompletedSummary(
      baseXpHint: 20,
      difficulty: MissionDifficultyLevel.moderate,
      completedAt: now,
    );
    final result = XpCalculationPolicy.evaluate(
      summary: summary,
      snapshot: emptySnapshot,
    );
    // 20 * 1.3 = 26
    expect(result.finalXpPreview, 26);
    expect(result.provisionalOnly, isTrue);
    expect(result.evaluationVersion, XpCalculationPolicy.evaluationVersion);
  });

  test(
    'a restorative mission scores lower than an advanced one, all else equal',
    () {
      final restorative = XpCalculationPolicy.evaluate(
        summary: testCompletedSummary(
          difficulty: MissionDifficultyLevel.restorative,
          completedAt: now,
        ),
        snapshot: emptySnapshot,
      );
      final advanced = XpCalculationPolicy.evaluate(
        summary: testCompletedSummary(
          difficulty: MissionDifficultyLevel.advanced,
          completedAt: now,
        ),
        snapshot: emptySnapshot,
      );
      expect(restorative.finalXpPreview, lessThan(advanced.finalXpPreview));
    },
  );

  test('a consistency bonus is added and capped at maxStreakBonus', () {
    final uncapped = XpCalculationPolicy.evaluate(
      summary: testCompletedSummary(completedAt: now),
      snapshot: const MissionHistorySnapshot(
        totalCompletions: 5,
        completionsByCategory: {},
        completionsByDefinitionId: {},
        categoriesTried: {},
        currentStreakDays: 3,
        longestStreakDays: 3,
        daysSinceLastCompletion: 1,
        advancedOrChallengingCompletions: 0,
        recoveryCompletions: 0,
        justReturnedFromInactivity: false,
      ),
    );
    expect(uncapped.consistencyBonus, 6); // 3 days * 2

    final capped = XpCalculationPolicy.evaluate(
      summary: testCompletedSummary(completedAt: now),
      snapshot: const MissionHistorySnapshot(
        totalCompletions: 50,
        completionsByCategory: {},
        completionsByDefinitionId: {},
        categoriesTried: {},
        currentStreakDays: 100,
        longestStreakDays: 100,
        daysSinceLastCompletion: 1,
        advancedOrChallengingCompletions: 0,
        recoveryCompletions: 0,
        justReturnedFromInactivity: false,
      ),
    );
    expect(capped.consistencyBonus, XpCalculationPolicy.maxStreakBonus);
  });

  test('a recovery mission gets the flat recovery bonus', () {
    final result = XpCalculationPolicy.evaluate(
      summary: testCompletedSummary(recoveryMission: true, completedAt: now),
      snapshot: emptySnapshot,
    );
    expect(result.recoveryBonus, XpCalculationPolicy.maxRecoveryBonus);
  });

  test('repeating the same mission recently produces a shrinking result '
      'each time (diminishing returns), never reaching zero', () {
    final fresh = XpCalculationPolicy.evaluate(
      summary: testCompletedSummary(
        definitionId: 'repeat-me',
        completedAt: now,
      ),
      snapshot: const MissionHistorySnapshot(
        totalCompletions: 0,
        completionsByCategory: {},
        completionsByDefinitionId: {},
        categoriesTried: {},
        currentStreakDays: 0,
        longestStreakDays: 0,
        daysSinceLastCompletion: -1,
        advancedOrChallengingCompletions: 0,
        recoveryCompletions: 0,
        justReturnedFromInactivity: false,
      ),
    );

    int repeatResultFor(int priorCompletions) {
      return XpCalculationPolicy.evaluate(
        summary: testCompletedSummary(
          definitionId: 'repeat-me',
          completedAt: now,
        ),
        snapshot: MissionHistorySnapshot(
          totalCompletions: priorCompletions,
          completionsByCategory: const {},
          completionsByDefinitionId: {'repeat-me': priorCompletions},
          categoriesTried: const {},
          currentStreakDays: 0,
          longestStreakDays: 0,
          daysSinceLastCompletion: 0,
          advancedOrChallengingCompletions: 0,
          recoveryCompletions: 0,
          justReturnedFromInactivity: false,
        ),
      ).finalXpPreview;
    }

    final once = repeatResultFor(1);
    final twice = repeatResultFor(2);
    final many = repeatResultFor(20);

    expect(once, lessThan(fresh.finalXpPreview));
    expect(twice, lessThanOrEqualTo(once));
    expect(many, greaterThan(0)); // never fully zeroed out.
  });

  test(
    'a single mission never exceeds maxXpPerMission regardless of bonuses',
    () {
      final result = XpCalculationPolicy.evaluate(
        summary: testCompletedSummary(
          baseXpHint: 1000,
          difficulty: MissionDifficultyLevel.advanced,
          recoveryMission: true,
          completedAt: now,
        ),
        snapshot: const MissionHistorySnapshot(
          totalCompletions: 100,
          completionsByCategory: {},
          completionsByDefinitionId: {},
          categoriesTried: {},
          currentStreakDays: 365,
          longestStreakDays: 365,
          daysSinceLastCompletion: 0,
          advancedOrChallengingCompletions: 50,
          recoveryCompletions: 10,
          justReturnedFromInactivity: false,
        ),
      );
      expect(
        result.finalXpPreview,
        lessThanOrEqualTo(XpCalculationPolicy.maxXpPerMission),
      );
    },
  );

  test('the daily cap clamps the preview once today\'s allowance is spent', () {
    final result = XpCalculationPolicy.evaluate(
      summary: testCompletedSummary(completedAt: now),
      snapshot: emptySnapshot,
      xpAlreadyEarnedToday: XpCalculationPolicy.maxDailyXpPreview - 5,
    );
    expect(result.finalXpPreview, lessThanOrEqualTo(5));
  });

  test('the daily cap never lets the preview go negative', () {
    final result = XpCalculationPolicy.evaluate(
      summary: testCompletedSummary(completedAt: now),
      snapshot: emptySnapshot,
      xpAlreadyEarnedToday: XpCalculationPolicy.maxDailyXpPreview + 100,
    );
    expect(result.finalXpPreview, 0);
  });

  test('identical inputs always produce an identical result (determinism)', () {
    final summary = testCompletedSummary(completedAt: now);
    final a = XpCalculationPolicy.evaluate(
      summary: summary,
      snapshot: emptySnapshot,
    );
    final b = XpCalculationPolicy.evaluate(
      summary: summary,
      snapshot: emptySnapshot,
    );
    expect(a.finalXpPreview, b.finalXpPreview);
    expect(a.reasons, b.reasons);
  });

  test('every evaluation is marked provisionalOnly', () {
    final result = XpCalculationPolicy.evaluate(
      summary: testCompletedSummary(completedAt: now),
      snapshot: emptySnapshot,
    );
    expect(result.provisionalOnly, isTrue);
  });
}
