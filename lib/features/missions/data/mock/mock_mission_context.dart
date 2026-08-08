import '../../domain/entities/behavioral_history.dart';
import '../../domain/entities/mission_result.dart';
import '../../domain/entities/user_discipline_profile.dart';
import '../../domain/enums/data_confidence.dart';
import '../../domain/enums/mission_category.dart';
import '../../domain/enums/mission_difficulty_level.dart';
import '../../domain/enums/mission_result_status.dart';

/// Deterministic canned (profile, history, "now") triples — mirrors
/// `DashboardMockScenario`'s pattern. Every scenario always returns exactly
/// the same values so selection stays reproducible in tests and goldens.
enum MockMissionContextScenario {
  normalActive,
  firstDay,
  recoveryMode,
  lowAvailableTime,
  categoryPreference,
  accessibilityAlternative,
  noIdealCandidateFallback,
}

typedef MockMissionContext = ({
  UserDisciplineProfile profile,
  BehavioralHistory history,
  DateTime now,
});

abstract final class MockMissionContexts {
  static final DateTime referenceDate = DateTime.utc(2026, 8, 5, 9);
  static final DateTime _yesterday = referenceDate.subtract(
    const Duration(days: 1),
  );
  static final DateTime _twoDaysAgo = referenceDate.subtract(
    const Duration(days: 2),
  );

  static MockMissionContext forScenario(MockMissionContextScenario scenario) {
    return switch (scenario) {
      MockMissionContextScenario.normalActive => _normalActive(),
      MockMissionContextScenario.firstDay => _firstDay(),
      MockMissionContextScenario.recoveryMode => _recoveryMode(),
      MockMissionContextScenario.lowAvailableTime => _lowAvailableTime(),
      MockMissionContextScenario.categoryPreference => _categoryPreference(),
      MockMissionContextScenario.accessibilityAlternative =>
        _accessibilityAlternative(),
      MockMissionContextScenario.noIdealCandidateFallback =>
        _noIdealCandidateFallback(),
    };
  }

  static MockMissionContext _normalActive() {
    return (
      profile: const UserDisciplineProfile(
        userId: 'mock-user',
        preferredCategories: {MissionCategory.fitness},
        availableMinutesToday: 20,
        fitnessSelfAssessment: FitnessSelfAssessment.moderate,
      ),
      history: BehavioralHistory(
        completionRate7Days: 0.8,
        completionRate30Days: 0.75,
        consecutiveSuccesses: 2,
        currentStreak: 5,
        longestStreak: 12,
        lastCompletedAt: _yesterday,
        recentMissionIds: const ['fit-squats-10', 'code-review-1'],
        recentMissionResults: [
          MissionResult(
            missionId: 'fit-squats-10',
            category: MissionCategory.fitness,
            assignedDifficulty: MissionDifficultyLevel.easy,
            assignedAt: _yesterday,
            completedAt: _yesterday,
            status: MissionResultStatus.completed,
            actualMinutes: 5,
            selfReportedEffort: 2,
          ),
          MissionResult(
            missionId: 'code-review-1',
            category: MissionCategory.coding,
            assignedDifficulty: MissionDifficultyLevel.easy,
            assignedAt: _twoDaysAgo,
            completedAt: _twoDaysAgo,
            status: MissionResultStatus.completed,
            actualMinutes: 10,
            selfReportedEffort: 2,
          ),
        ],
        categoryPerformance: const {
          MissionCategory.fitness: CategoryPerformance(
            category: MissionCategory.fitness,
            completed: 4,
            missed: 1,
            averageEffort: 2.5,
            lastDifficulty: MissionDifficultyLevel.easy,
            consecutiveComparableSuccesses: 1,
          ),
        },
        dataConfidence: DataConfidence.medium,
      ),
      now: referenceDate,
    );
  }

  static MockMissionContext _firstDay() {
    return (
      profile: const UserDisciplineProfile(
        userId: 'mock-user-new',
        availableMinutesToday: 15,
      ),
      history: const BehavioralHistory(),
      now: referenceDate,
    );
  }

  static MockMissionContext _recoveryMode() {
    return (
      profile: const UserDisciplineProfile(
        userId: 'mock-user-recovery',
        recoveryModeActive: true,
        availableMinutesToday: 15,
        preferredCategories: {MissionCategory.fitness},
      ),
      history: BehavioralHistory(
        completionRate7Days: 0.2,
        completionRate30Days: 0.4,
        consecutiveMisses: 3,
        currentStreak: 0,
        longestStreak: 18,
        lastCompletedAt: referenceDate.subtract(const Duration(days: 4)),
        dataConfidence: DataConfidence.medium,
      ),
      now: referenceDate,
    );
  }

  static MockMissionContext _lowAvailableTime() {
    return (
      profile: const UserDisciplineProfile(
        userId: 'mock-user-low-time',
        preferredCategories: {MissionCategory.reading},
        availableMinutesToday: 8,
      ),
      history: const BehavioralHistory(dataConfidence: DataConfidence.low),
      now: referenceDate,
    );
  }

  static MockMissionContext _categoryPreference() {
    return (
      profile: const UserDisciplineProfile(
        userId: 'mock-user-coding',
        preferredCategories: {MissionCategory.coding},
        availableMinutesToday: 20,
      ),
      history: const BehavioralHistory(
        completionRate7Days: 0.9,
        categoryPerformance: {
          MissionCategory.coding: CategoryPerformance(
            category: MissionCategory.coding,
            completed: 6,
            missed: 0,
            averageEffort: 2.0,
            lastDifficulty: MissionDifficultyLevel.easy,
            consecutiveComparableSuccesses: 3,
          ),
        },
        dataConfidence: DataConfidence.high,
      ),
      now: referenceDate,
    );
  }

  static MockMissionContext _accessibilityAlternative() {
    return (
      profile: const UserDisciplineProfile(
        userId: 'mock-user-accessibility',
        preferredCategories: {MissionCategory.fitness},
        healthLimitations: {'knee_sensitive'},
        availableMinutesToday: 20,
      ),
      history: const BehavioralHistory(dataConfidence: DataConfidence.low),
      now: referenceDate,
    );
  }

  static MockMissionContext _noIdealCandidateFallback() {
    return (
      profile: UserDisciplineProfile(
        userId: 'mock-user-fallback',
        avoidedCategories: MissionCategory.values.toSet(),
        availableMinutesToday: 15,
      ),
      history: const BehavioralHistory(),
      now: referenceDate,
    );
  }
}
