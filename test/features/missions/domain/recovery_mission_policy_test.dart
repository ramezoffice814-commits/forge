import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/entities/behavioral_history.dart';
import 'package:forge/features/missions/domain/entities/mission_result.dart';
import 'package:forge/features/missions/domain/entities/user_discipline_profile.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/missions/domain/enums/mission_result_status.dart';
import 'package:forge/features/missions/domain/policies/recovery_mission_policy.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);
  const profile = UserDisciplineProfile(userId: 'u1');

  test('a manual override always wins, in either direction', () {
    final forcedOn = RecoveryMissionPolicy.resolve(
      profile: profile,
      history: const BehavioralHistory(),
      currentDateTime: now,
      override: true,
    );
    expect(forcedOn.active, isTrue);

    final activeProfile = profile.copyWith(recoveryModeActive: true);
    final forcedOff = RecoveryMissionPolicy.resolve(
      profile: activeProfile,
      history: const BehavioralHistory(),
      currentDateTime: now,
      override: false,
    );
    expect(forcedOff.active, isFalse);
  });

  test('the user\'s own recovery-mode flag activates recovery', () {
    final decision = RecoveryMissionPolicy.resolve(
      profile: profile.copyWith(recoveryModeActive: true),
      history: const BehavioralHistory(),
      currentDateTime: now,
    );
    expect(decision.active, isTrue);
  });

  test('three or more consecutive misses activate recovery', () {
    final decision = RecoveryMissionPolicy.resolve(
      profile: profile,
      history: const BehavioralHistory(consecutiveMisses: 3),
      currentDateTime: now,
    );
    expect(decision.active, isTrue);
  });

  test('prolonged inactivity (3+ days since last completion) activates '
      'recovery', () {
    final decision = RecoveryMissionPolicy.resolve(
      profile: profile,
      history: BehavioralHistory(
        lastCompletedAt: now.subtract(const Duration(days: 4)),
      ),
      currentDateTime: now,
    );
    expect(decision.active, isTrue);
  });

  test('a low 7-day completion rate activates recovery', () {
    final decision = RecoveryMissionPolicy.resolve(
      profile: profile,
      history: BehavioralHistory(
        completionRate7Days: 0.1,
        recentMissionResults: [
          MissionResult(
            missionId: 'm1',
            category: MissionCategory.fitness,
            assignedDifficulty: MissionDifficultyLevel.easy,
            assignedAt: now.subtract(const Duration(days: 1)),
            status: MissionResultStatus.skipped,
          ),
        ],
      ),
      currentDateTime: now,
    );
    expect(decision.active, isTrue);
  });

  test('a healthy, active profile does not trigger recovery', () {
    final decision = RecoveryMissionPolicy.resolve(
      profile: profile,
      history: BehavioralHistory(
        completionRate7Days: 0.9,
        lastCompletedAt: now.subtract(const Duration(hours: 12)),
      ),
      currentDateTime: now,
    );
    expect(decision.active, isFalse);
    expect(decision.reason, isNull);
  });

  test('recovery reasons are neutral, never shaming language', () {
    final decision = RecoveryMissionPolicy.resolve(
      profile: profile,
      history: const BehavioralHistory(consecutiveMisses: 3),
      currentDateTime: now,
    );
    for (final phrase in ['fail', 'lazy', 'weak', 'broke']) {
      expect(
        decision.reason?.toLowerCase().contains(phrase) ?? false,
        isFalse,
        reason: phrase,
      );
    }
  });
}
