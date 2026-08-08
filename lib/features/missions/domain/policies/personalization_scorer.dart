import '../entities/behavioral_history.dart';
import '../entities/mission_candidate_score.dart';
import '../entities/mission_definition.dart';
import '../entities/user_discipline_profile.dart';
import '../enums/mission_difficulty_level.dart';
import 'mission_variety_policy.dart';
import 'time_budget_policy.dart';

/// Deterministic, weighted scoring for candidates that already survived
/// every hard filter. Weights are centralized here and are product
/// defaults — not scientifically validated — tunable later from real data
/// without touching any policy's logic.
abstract final class PersonalizationScorer {
  static const Map<String, double> weights = {
    'goalRelevance': 0.12,
    'preferredCategory': 0.15,
    'recentCategorySuccess': 0.12,
    'difficultyFit': 0.15,
    'timeFit': 0.15,
    'variety': 0.10,
    'progressionContinuity': 0.08,
    'preferredActiveTime': 0.05,
    'recoveryCompatibility': 0.08,
  };

  static MissionCandidateScore score({
    required MissionDefinition mission,
    required UserDisciplineProfile profile,
    required BehavioralHistory history,
    required List<MissionDefinition> catalog,
    required MissionDifficultyLevel resolvedDifficulty,
    required int resolvedDuration,
    required bool recoveryActive,
    required DateTime currentDateTime,
  }) {
    final factors = <String, double>{
      'goalRelevance': _goalRelevance(mission, profile),
      'preferredCategory':
          profile.preferredCategories.contains(mission.category) ? 1.0 : 0.5,
      'recentCategorySuccess': _recentCategorySuccess(mission, history),
      'difficultyFit': _difficultyFit(mission, resolvedDifficulty),
      'timeFit': TimeBudgetPolicy.timeFitScore(
        resolvedMinutes: resolvedDuration,
        availableMinutesToday: profile.availableMinutesToday,
        preferredDuration:
            profile.preferredMissionDuration ?? mission.estimatedMinutes,
      ),
      'variety': 1 - MissionVarietyPolicy.repetitionPenalty(mission, history),
      'progressionContinuity': _progressionContinuity(
        mission,
        history,
        catalog,
      ),
      'preferredActiveTime': _preferredActiveTime(profile, currentDateTime),
      'recoveryCompatibility': recoveryActive
          ? (mission.recoveryEligible ? 1.0 : 0.0)
          : 0.5,
    };

    var total = 0.0;
    factors.forEach((factor, value) {
      total += (weights[factor] ?? 0) * value;
    });

    return MissionCandidateScore(
      mission: mission,
      factorScores: factors,
      total: total,
    );
  }

  static double _goalRelevance(
    MissionDefinition mission,
    UserDisciplineProfile profile,
  ) {
    if (profile.selectedGoals.isEmpty || mission.allowedGoalTypes.isEmpty) {
      return 0.5;
    }
    return mission.allowedGoalTypes
            .intersection(profile.selectedGoals)
            .isNotEmpty
        ? 1.0
        : 0.2;
  }

  static double _recentCategorySuccess(
    MissionDefinition mission,
    BehavioralHistory history,
  ) {
    final performance = history.performanceFor(mission.category);
    return performance.totalAttempts == 0 ? 0.5 : performance.successRate;
  }

  static double _difficultyFit(
    MissionDefinition mission,
    MissionDifficultyLevel resolvedDifficulty,
  ) {
    final distance = (mission.baseDifficulty.index - resolvedDifficulty.index)
        .abs();
    return (1 - (distance / (MissionDifficultyLevel.values.length - 1)))
        .clamp(0, 1)
        .toDouble();
  }

  static double _progressionContinuity(
    MissionDefinition mission,
    BehavioralHistory history,
    List<MissionDefinition> catalog,
  ) {
    if (mission.progressionGroup == null) return 0.5;
    final catalogById = {for (final m in catalog) m.id: m};

    for (final result in history.recentMissionResults) {
      if (!result.isSuccess) continue;
      final previousDefinition = catalogById[result.missionId];
      if (previousDefinition?.progressionGroup != mission.progressionGroup) {
        continue;
      }
      final previousStep = previousDefinition!.progressionStep ?? 0;
      final thisStep = mission.progressionStep ?? 0;
      if (thisStep == previousStep + 1) return 1.0;
      if (thisStep <= previousStep) return 0.3;
    }
    return 0.5;
  }

  static double _preferredActiveTime(
    UserDisciplineProfile profile,
    DateTime currentDateTime,
  ) {
    if (profile.preferredActiveHours.isEmpty) return 0.5;
    return profile.preferredActiveHours.contains(currentDateTime.hour)
        ? 1.0
        : 0.5;
  }
}
