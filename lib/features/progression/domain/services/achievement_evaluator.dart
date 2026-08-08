import '../entities/achievement_definition.dart';
import '../entities/achievement_evaluation_result.dart';
import '../entities/achievement_progress.dart';
import '../entities/mission_history_snapshot.dart';

/// Reads a [MissionHistorySnapshot] plus the set of already-unlocked ids and
/// returns every achievement's current state — deterministic, and never
/// re-unlocks (or re-announces) something already in [unlockedIds].
abstract final class AchievementEvaluator {
  static AchievementEvaluationResult evaluate({
    required MissionHistorySnapshot snapshot,
    required Set<String> unlockedIds,
    required List<AchievementDefinition> catalog,
    DateTime? unlockTimestampForNew,
  }) {
    final newlyUnlocked = <AchievementProgress>[];
    final alreadyUnlocked = <AchievementProgress>[];
    final progressUpdates = <AchievementProgress>[];
    final reasons = <String>[];

    for (final definition in catalog) {
      if (!definition.active) continue;

      final (current, target) = definition.criteria.progress(snapshot);
      final clampedCurrent = current.clamp(0, target);
      final wasUnlocked = unlockedIds.contains(definition.id);
      final meetsCriteria = target > 0 && clampedCurrent >= target;

      if (wasUnlocked) {
        alreadyUnlocked.add(
          AchievementProgress(
            definition: definition,
            status: AchievementStatus.unlocked,
            current: clampedCurrent,
            target: target,
          ),
        );
        continue;
      }

      if (meetsCriteria) {
        final progress = AchievementProgress(
          definition: definition,
          status: AchievementStatus.unlocked,
          current: clampedCurrent,
          target: target,
          unlockedAt: unlockTimestampForNew,
        );
        newlyUnlocked.add(progress);
        reasons.add('"${definition.name}" unlocked: ${definition.description}');
        continue;
      }

      progressUpdates.add(
        AchievementProgress(
          definition: definition,
          status: clampedCurrent > 0
              ? AchievementStatus.progressing
              : AchievementStatus.locked,
          current: clampedCurrent,
          target: target,
        ),
      );
    }

    return AchievementEvaluationResult(
      newlyUnlocked: newlyUnlocked,
      alreadyUnlocked: alreadyUnlocked,
      progressUpdates: progressUpdates,
      reasons: reasons,
    );
  }
}
