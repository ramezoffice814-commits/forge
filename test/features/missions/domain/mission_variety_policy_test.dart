import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/entities/behavioral_history.dart';
import 'package:forge/features/missions/domain/entities/mission_definition.dart';
import 'package:forge/features/missions/domain/entities/mission_result.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/missions/domain/enums/mission_result_status.dart';
import 'package:forge/features/missions/domain/enums/proof_policy.dart';
import 'package:forge/features/missions/domain/enums/safety_classification.dart';
import 'package:forge/features/missions/domain/policies/mission_variety_policy.dart';

MissionDefinition _mission({
  int repeatCooldownDays = 2,
  int maximumOccurrencesPerWeek = 3,
}) {
  return MissionDefinition(
    id: 'm1',
    version: 1,
    title: 'Test Mission',
    description: 'desc',
    category: MissionCategory.fitness,
    baseDifficulty: MissionDifficultyLevel.easy,
    minimumDifficulty: MissionDifficultyLevel.easy,
    maximumDifficulty: MissionDifficultyLevel.easy,
    estimatedMinutes: 5,
    minimumMinutes: 3,
    maximumMinutes: 10,
    baseXpHint: 10,
    completionConditions: const ['Do it'],
    proofPolicy: ProofPolicy.none,
    safetyClassification: SafetyClassification.standard,
    recoveryEligible: true,
    repeatCooldownDays: repeatCooldownDays,
    maximumOccurrencesPerWeek: maximumOccurrencesPerWeek,
    active: true,
  );
}

MissionResult _result(
  String missionId,
  DateTime assignedAt, {
  MissionCategory category = MissionCategory.fitness,
}) {
  return MissionResult(
    missionId: missionId,
    category: category,
    assignedDifficulty: MissionDifficultyLevel.easy,
    assignedAt: assignedAt,
    status: MissionResultStatus.completed,
  );
}

void main() {
  final now = DateTime.utc(2026, 8, 10);

  test('a mission assigned within its cooldown window is on cooldown', () {
    final history = BehavioralHistory(
      recentMissionResults: [
        _result('m1', now.subtract(const Duration(days: 1))),
      ],
    );
    expect(
      MissionVarietyPolicy.isWithinCooldown(_mission(), history, now),
      isTrue,
    );
  });

  test('a mission assigned before its cooldown window has cleared it', () {
    final history = BehavioralHistory(
      recentMissionResults: [
        _result('m1', now.subtract(const Duration(days: 5))),
      ],
    );
    expect(
      MissionVarietyPolicy.isWithinCooldown(_mission(), history, now),
      isFalse,
    );
  });

  test('zero cooldown days means never on cooldown', () {
    final history = BehavioralHistory(
      recentMissionResults: [_result('m1', now)],
    );
    expect(
      MissionVarietyPolicy.isWithinCooldown(
        _mission(repeatCooldownDays: 0),
        history,
        now,
      ),
      isFalse,
    );
  });

  test('the weekly occurrence limit is enforced within the last 7 days', () {
    final history = BehavioralHistory(
      recentMissionResults: [
        _result('m1', now.subtract(const Duration(days: 1))),
        _result('m1', now.subtract(const Duration(days: 3))),
        _result('m1', now.subtract(const Duration(days: 5))),
      ],
    );
    expect(
      MissionVarietyPolicy.exceedsWeeklyLimit(
        _mission(maximumOccurrencesPerWeek: 3),
        history,
        now,
      ),
      isTrue,
    );
  });

  test(
    'occurrences older than 7 days do not count toward the weekly limit',
    () {
      final history = BehavioralHistory(
        recentMissionResults: [
          _result('m1', now.subtract(const Duration(days: 10))),
          _result('m1', now.subtract(const Duration(days: 12))),
        ],
      );
      expect(
        MissionVarietyPolicy.exceedsWeeklyLimit(
          _mission(maximumOccurrencesPerWeek: 3),
          history,
          now,
        ),
        isFalse,
      );
    },
  );

  test('a mission used yesterday is penalized more than a fresh one', () {
    final repeatedHistory = BehavioralHistory(
      recentMissionIds: const ['m1'],
      recentMissionResults: [
        _result('m1', now.subtract(const Duration(days: 1))),
      ],
    );
    const freshHistory = BehavioralHistory();

    final repeatedPenalty = MissionVarietyPolicy.repetitionPenalty(
      _mission(),
      repeatedHistory,
    );
    final freshPenalty = MissionVarietyPolicy.repetitionPenalty(
      _mission(),
      freshHistory,
    );
    expect(repeatedPenalty, greaterThan(freshPenalty));
    expect(freshPenalty, 0);
  });
}
