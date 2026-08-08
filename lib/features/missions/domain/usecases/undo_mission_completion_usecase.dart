import '../aggregates/mission_aggregate.dart';
import '../aggregates/mission_lifecycle_exception.dart';
import '../aggregates/mission_transition_failure.dart';
import '../events/mission_event.dart';
import '../events/mission_event_id_generator.dart';
import '../events/mission_event_source.dart';
import '../repositories/mission_event_repository.dart';
import '../sessions/mission_clock.dart';
import 'mission_event_append_helper.dart';

/// Undoing completion is only allowed briefly after the fact and only
/// before any reward has been server-confirmed — see
/// `MissionAggregate.canUndoCompletion` for the reward-state half of this
/// check; [undoWindow] is the additional time-based gate this use case owns.
class UndoMissionCompletionUseCase {
  const UndoMissionCompletionUseCase(
    this._repository, {
    this._clock = const SystemMissionClock(),
    this.undoWindow = const Duration(minutes: 15),
  });

  final MissionEventRepository _repository;
  final MissionClock _clock;
  final Duration undoWindow;

  Future<MissionAggregate> call({
    required MissionAggregate aggregate,
    required String userId,
    String? reason,
  }) async {
    if (!aggregate.canUndoCompletion) {
      throw MissionLifecycleException(
        MissionTransitionFailure(
          reason: TransitionFailureReason.invalidTransition,
          message: "This mission's completion can't be undone right now.",
          currentState: aggregate.lifecycleState,
          attemptedEvent: MissionEventType.completionUndone,
        ),
      );
    }

    final completedAt = aggregate.completedAt;
    final now = _clock.now();
    if (completedAt != null && now.difference(completedAt) > undoWindow) {
      throw MissionLifecycleException(
        MissionTransitionFailure(
          reason: TransitionFailureReason.outsideUndoWindow,
          message:
              'Completion can only be undone within '
              '${undoWindow.inMinutes} minutes.',
          currentState: aggregate.lifecycleState,
          attemptedEvent: MissionEventType.completionUndone,
        ),
      );
    }

    final draft = MissionCompletionUndone(
      eventId: MissionEventIdGenerator.newEventId(),
      missionInstanceId: aggregate.instance.instanceId,
      userId: userId,
      occurredAt: now,
      clientCreatedAt: now,
      sequenceNumber: 0,
      source: MissionEventSource.userAction,
      idempotencyKey: MissionEventIdGenerator.newEventId(),
      reason: reason,
    );
    return appendAndRehydrate(_repository, aggregate.instance, draft);
  }
}
