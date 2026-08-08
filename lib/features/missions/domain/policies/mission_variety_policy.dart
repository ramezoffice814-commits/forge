import '../entities/behavioral_history.dart';
import '../entities/mission_definition.dart';

/// Repeat-cooldown/weekly-limit are hard rules (the engine drops a
/// violating candidate outright); the repetition penalty below is a soft
/// scoring input — recent repetition should nudge selection away from a
/// mission/category, never hard-ban useful routine.
abstract final class MissionVarietyPolicy {
  static bool isWithinCooldown(
    MissionDefinition mission,
    BehavioralHistory history,
    DateTime now,
  ) {
    if (mission.repeatCooldownDays <= 0) return false;
    final cutoff = now.subtract(Duration(days: mission.repeatCooldownDays));
    return history.recentMissionResults.any(
      (r) => r.missionId == mission.id && !r.assignedAt.isBefore(cutoff),
    );
  }

  static bool exceedsWeeklyLimit(
    MissionDefinition mission,
    BehavioralHistory history,
    DateTime now,
  ) {
    final weekAgo = now.subtract(const Duration(days: 7));
    final occurrences = history.recentMissionResults
        .where(
          (r) => r.missionId == mission.id && r.assignedAt.isAfter(weekAgo),
        )
        .length;
    return occurrences >= mission.maximumOccurrencesPerWeek;
  }

  /// 0 (fresh) – 1 (heavily repeated): looks at how recently the exact
  /// mission and its category last appeared.
  static double repetitionPenalty(
    MissionDefinition mission,
    BehavioralHistory history,
  ) {
    var penalty = 0.0;

    final recentIds = history.recentMissionIds.take(3).toList();
    final idxOfMission = recentIds.indexOf(mission.id);
    if (idxOfMission == 0) {
      penalty += 0.6;
    } else if (idxOfMission > 0) {
      penalty += 0.3;
    }

    final sameCategoryYesterday = history.recentMissionResults
        .take(2)
        .any((r) => r.category == mission.category);
    if (sameCategoryYesterday) penalty += 0.25;

    return penalty.clamp(0, 1).toDouble();
  }
}
