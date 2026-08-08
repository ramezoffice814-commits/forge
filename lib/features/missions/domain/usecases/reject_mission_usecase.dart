import '../aggregates/mission_aggregate.dart';
import '../aggregates/mission_lifecycle_exception.dart';
import '../aggregates/mission_transition_failure.dart';
import '../enums/rejection_reason.dart';
import '../events/mission_event.dart';
import '../events/mission_event_id_generator.dart';
import '../events/mission_event_source.dart';
import '../repositories/mission_event_repository.dart';
import 'mission_event_append_helper.dart';

/// Records a rejection against the *current* mission stream. The
/// replacement mission is expected to already exist by the time this is
/// called — the caller selects it via `MissionSelectionController
/// .rejectMission()` first, then passes its id here, so this event never
/// needs to be edited after the fact to link the two.
class RejectMissionUseCase {
  const RejectMissionUseCase(this._repository);

  final MissionEventRepository _repository;

  Future<MissionAggregate> call({
    required MissionAggregate aggregate,
    required String userId,
    required RejectionReason reason,
    String? replacementMissionInstanceId,
  }) async {
    if (!aggregate.canReject) {
      throw MissionLifecycleException(
        MissionTransitionFailure(
          reason: TransitionFailureReason.invalidTransition,
          message: "This mission can't be rejected from its current state.",
          currentState: aggregate.lifecycleState,
          attemptedEvent: MissionEventType.rejected,
        ),
      );
    }

    final now = DateTime.now().toUtc();
    final draft = MissionRejected(
      eventId: MissionEventIdGenerator.newEventId(),
      missionInstanceId: aggregate.instance.instanceId,
      userId: userId,
      occurredAt: now,
      clientCreatedAt: now,
      sequenceNumber: 0,
      source: MissionEventSource.userAction,
      idempotencyKey: MissionEventIdGenerator.singleton(
        aggregate.instance.instanceId,
        'rejected',
      ),
      reason: reason,
      replacementMissionInstanceId: replacementMissionInstanceId,
    );
    return appendAndRehydrate(_repository, aggregate.instance, draft);
  }
}
