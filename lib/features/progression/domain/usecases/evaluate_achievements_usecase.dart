import '../entities/achievement_evaluation_result.dart';
import '../events/progression_event.dart';
import '../repositories/progression_repository.dart';
import '../services/achievement_evaluator.dart';
import '../services/mission_history_snapshot_builder.dart';

/// Re-evaluates every achievement and records an `AchievementUnlocked`
/// event for each one newly crossing its criteria — never re-unlocks (or
/// re-records) one already present in the event log.
class EvaluateAchievementsUseCase {
  const EvaluateAchievementsUseCase(this._repository);

  final ProgressionRepository _repository;

  Future<AchievementEvaluationResult> call(
    String userId, {
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final snapshot = MissionHistorySnapshotBuilder.build(
      _repository.completionsForUser(userId),
      asOf: effectiveNow,
    );
    final priorUnlocked = _repository
        .eventsForUser(userId)
        .whereType<AchievementUnlocked>()
        .map((e) => e.achievementId)
        .toSet();

    final result = AchievementEvaluator.evaluate(
      snapshot: snapshot,
      unlockedIds: priorUnlocked,
      catalog: _repository.getAchievementDefinitions(),
      unlockTimestampForNew: effectiveNow,
    );

    for (final unlocked in result.newlyUnlocked) {
      await _repository.appendEvent(
        AchievementUnlocked(
          eventId: '${unlocked.definition.id}-unlock',
          userId: userId,
          occurredAt: effectiveNow,
          sequenceNumber: 0,
          achievementId: unlocked.definition.id,
        ),
      );
    }

    return result;
  }
}
