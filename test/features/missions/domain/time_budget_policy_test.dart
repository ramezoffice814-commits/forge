import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/entities/mission_definition.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/missions/domain/enums/proof_policy.dart';
import 'package:forge/features/missions/domain/enums/safety_classification.dart';
import 'package:forge/features/missions/domain/policies/time_budget_policy.dart';

MissionDefinition _mission({
  int minimumMinutes = 5,
  int estimatedMinutes = 10,
  int maximumMinutes = 20,
}) {
  return MissionDefinition(
    id: 'm1',
    version: 1,
    title: 'Test Mission',
    description: 'desc',
    category: MissionCategory.reading,
    baseDifficulty: MissionDifficultyLevel.easy,
    minimumDifficulty: MissionDifficultyLevel.easy,
    maximumDifficulty: MissionDifficultyLevel.easy,
    estimatedMinutes: estimatedMinutes,
    minimumMinutes: minimumMinutes,
    maximumMinutes: maximumMinutes,
    baseXpHint: 10,
    completionConditions: const ['Do it'],
    proofPolicy: ProofPolicy.none,
    safetyClassification: SafetyClassification.standard,
    recoveryEligible: true,
    repeatCooldownDays: 0,
    maximumOccurrencesPerWeek: 7,
    active: true,
  );
}

void main() {
  test('a mission comfortably fits within a generous window', () {
    final resolution = TimeBudgetPolicy.resolve(
      mission: _mission(),
      availableMinutesToday: 30,
    );
    expect(resolution.fits, isTrue);
    expect(resolution.resolvedMinutes, 10);
  });

  test('an oversized mission (minimum exceeds budget) does not fit', () {
    final resolution = TimeBudgetPolicy.resolve(
      mission: _mission(
        minimumMinutes: 15,
        estimatedMinutes: 20,
        maximumMinutes: 25,
      ),
      availableMinutesToday: 10,
    );
    expect(resolution.fits, isFalse);
  });

  test('duration scales down to fit but never below the mission minimum', () {
    final resolution = TimeBudgetPolicy.resolve(
      mission: _mission(
        minimumMinutes: 5,
        estimatedMinutes: 10,
        maximumMinutes: 20,
      ),
      availableMinutesToday: 7,
    );
    expect(resolution.fits, isTrue);
    // budget = 7 - 2 (setup margin) = 5, clamped to the mission's minimum.
    expect(resolution.resolvedMinutes, 5);
    expect(resolution.resolvedMinutes, greaterThanOrEqualTo(5));
  });

  test('a requested duration is respected within the mission\'s bounds', () {
    final resolution = TimeBudgetPolicy.resolve(
      mission: _mission(
        minimumMinutes: 5,
        estimatedMinutes: 10,
        maximumMinutes: 20,
      ),
      availableMinutesToday: 30,
      requestedDuration: 15,
    );
    expect(resolution.resolvedMinutes, 15);
  });

  test('timeFitScore prefers durations close to the preferred one', () {
    final close = TimeBudgetPolicy.timeFitScore(
      resolvedMinutes: 10,
      availableMinutesToday: 30,
      preferredDuration: 10,
    );
    final far = TimeBudgetPolicy.timeFitScore(
      resolvedMinutes: 25,
      availableMinutesToday: 30,
      preferredDuration: 10,
    );
    expect(close, greaterThan(far));
  });

  test('timeFitScore mildly penalizes consuming almost the entire window', () {
    final usesWholeWindow = TimeBudgetPolicy.timeFitScore(
      resolvedMinutes: 28,
      availableMinutesToday: 30,
      preferredDuration: 28,
    );
    final usesPartialWindow = TimeBudgetPolicy.timeFitScore(
      resolvedMinutes: 10,
      availableMinutesToday: 30,
      preferredDuration: 10,
    );
    expect(usesPartialWindow, greaterThan(usesWholeWindow));
  });
}
