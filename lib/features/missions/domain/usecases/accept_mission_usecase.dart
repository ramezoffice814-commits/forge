import '../aggregates/mission_aggregate.dart';
import '../aggregates/mission_lifecycle_exception.dart';
import '../aggregates/mission_transition_failure.dart';
import '../events/mission_event.dart';
import '../events/mission_event_id_generator.dart';
import '../events/mission_event_source.dart';
import '../repositories/mission_event_repository.dart';
import 'mission_event_append_helper.dart';

/// Accepts an assigned mission. The fixed idempotency key is what makes a
/// double-tap (or a duplicate call from both Dashboard and Transmission)
/// resolve to one acceptance rather than two.
class AcceptMissionUseCase {
  const AcceptMissionUseCase(this._repository);

  final MissionEventRepository _repository;

  Future<MissionAggregate> call({
    required MissionAggregate aggregate,
    required String userId,
  }) async {
    if (!aggregate.canAccept) {
      throw MissionLifecycleException(
        MissionTransitionFailure(
          reason: TransitionFailureReason.invalidTransition,
          message: "This mission can't be accepted from its current state.",
          currentState: aggregate.lifecycleState,
          attemptedEvent: MissionEventType.accepted,
        ),
      );
    }

    final now = DateTime.now().toUtc();
    final draft = MissionAccepted(
      eventId: MissionEventIdGenerator.newEventId(),
      missionInstanceId: aggregate.instance.instanceId,
      userId: userId,
      occurredAt: now,
      clientCreatedAt: now,
      sequenceNumber: 0,
      source: MissionEventSource.userAction,
      idempotencyKey: MissionEventIdGenerator.singleton(
        aggregate.instance.instanceId,
        'accepted',
      ),
    );

    try {
      return await appendAndRehydrate(_repository, aggregate.instance, draft);
    } on MissionEventDuplicateException {
      throw MissionLifecycleException(
        MissionTransitionFailure(
          reason: TransitionFailureReason.duplicateEvent,
          message: 'This mission was already accepted.',
          currentState: aggregate.lifecycleState,
          attemptedEvent: MissionEventType.accepted,
        ),
      );
    }
  }
}
