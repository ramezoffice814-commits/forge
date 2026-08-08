import '../aggregates/mission_aggregate.dart';
import '../aggregates/mission_lifecycle_exception.dart';
import '../aggregates/mission_transition_failure.dart';
import '../events/mission_event.dart';
import '../events/mission_event_id_generator.dart';
import '../events/mission_event_source.dart';
import '../progress/mission_progress_policy.dart';
import '../progress/mission_progress_state.dart';
import '../repositories/mission_event_repository.dart';
import '../sessions/mission_clock.dart';
import 'mission_event_append_helper.dart';

/// Every progress control (counter, timer, checklist, ...) funnels through
/// here rather than appending a `MissionProgressUpdated` event directly —
/// this is the one place `MissionProgressPolicy` is consulted, so no
/// control can bypass its bounds/monotonicity rules.
class UpdateMissionProgressUseCase {
  const UpdateMissionProgressUseCase(
    this._repository, {
    this._clock = const SystemMissionClock(),
  });

  final MissionEventRepository _repository;
  final MissionClock _clock;

  Future<MissionAggregate> call({
    required MissionAggregate aggregate,
    required String userId,
    required MissionProgressState proposed,
    bool isCorrection = false,
  }) async {
    if (!aggregate.canUpdateProgress) {
      throw MissionLifecycleException(
        MissionTransitionFailure(
          reason: TransitionFailureReason.invalidTransition,
          message: 'Start the mission before updating its progress.',
          currentState: aggregate.lifecycleState,
          attemptedEvent: MissionEventType.progressUpdated,
        ),
      );
    }

    final result = MissionProgressPolicy.evaluate(
      current: aggregate.progressState,
      proposed: proposed,
      isCorrection: isCorrection,
    );
    if (!result.isAccepted) {
      throw MissionLifecycleException(
        MissionTransitionFailure(
          reason: TransitionFailureReason.malformedEvent,
          message: _reasonMessage(result.reasonCodes),
          currentState: aggregate.lifecycleState,
          attemptedEvent: MissionEventType.progressUpdated,
        ),
      );
    }

    final now = _clock.now();
    final draft = MissionProgressUpdated(
      eventId: MissionEventIdGenerator.newEventId(),
      missionInstanceId: aggregate.instance.instanceId,
      userId: userId,
      occurredAt: now,
      clientCreatedAt: now,
      sequenceNumber: 0,
      source: MissionEventSource.userAction,
      idempotencyKey: MissionEventIdGenerator.newEventId(),
      progress: result.normalizedState,
      isCorrection: isCorrection,
    );
    return appendAndRehydrate(_repository, aggregate.instance, draft);
  }

  static String _reasonMessage(List<String> codes) {
    if (codes.contains('decreaseRequiresCorrection')) {
      return 'Progress can only decrease as an explicit correction.';
    }
    if (codes.contains('implausibleDurationJump')) {
      return "That update jumped further than we can trust — try a smaller update.";
    }
    if (codes.contains('unknownChecklistItem')) {
      return "That checklist item isn't part of this mission.";
    }
    if (codes.contains('mismatchedProgressType')) {
      return "That update doesn't match this mission's progress type.";
    }
    return "That update couldn't be applied.";
  }
}
