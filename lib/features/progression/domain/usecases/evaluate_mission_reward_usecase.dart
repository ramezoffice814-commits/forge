import '../entities/completed_mission_summary.dart';
import '../entities/xp_reward_evaluation.dart';
import '../events/progression_event.dart';
import '../policies/xp_calculation_policy.dart';
import '../repositories/progression_repository.dart';
import '../services/mission_history_snapshot_builder.dart';

/// The one place a mission's completion turns into an XP preview. Records
/// the completion and appends the resulting `XpPreviewCalculated` event —
/// callers never construct either directly.
class EvaluateMissionRewardUseCase {
  const EvaluateMissionRewardUseCase(this._repository);

  final ProgressionRepository _repository;

  Future<XpRewardEvaluation> call(CompletedMissionSummary summary) async {
    // The snapshot must reflect history *before* this completion — see
    // `XpCalculationPolicy`'s doc comment.
    final priorCompletions = _repository.completionsForUser(summary.userId);
    final priorSnapshot = MissionHistorySnapshotBuilder.build(
      priorCompletions,
      asOf: summary.completedAt,
    );

    final xpAlreadyEarnedToday = _xpEarnedOn(
      summary.userId,
      summary.completedAt,
    );

    final evaluation = XpCalculationPolicy.evaluate(
      summary: summary,
      snapshot: priorSnapshot,
      xpAlreadyEarnedToday: xpAlreadyEarnedToday,
    );

    await _repository.recordCompletion(summary);
    await _repository.appendEvent(
      XpPreviewCalculated(
        eventId: '${summary.missionInstanceId}-xp',
        userId: summary.userId,
        occurredAt: summary.completedAt,
        sequenceNumber: 0,
        evaluation: evaluation,
      ),
    );

    return evaluation;
  }

  int _xpEarnedOn(String userId, DateTime day) {
    return _repository
        .eventsForUser(userId)
        .whereType<XpPreviewCalculated>()
        .where((e) => _isSameDay(e.occurredAt, day))
        .fold(0, (sum, e) => sum + e.evaluation.finalXpPreview);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
