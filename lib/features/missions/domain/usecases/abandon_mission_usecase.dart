import '../aggregates/mission_aggregate.dart';
import '../aggregates/mission_lifecycle_exception.dart';
import '../aggregates/mission_transition_failure.dart';
import '../events/mission_event.dart';
import '../events/mission_event_id_generator.dart';
import '../events/mission_event_source.dart';
import '../repositories/mission_event_repository.dart';
import 'mission_event_append_helper.dart';

/// Abandoning is terminal (see `MissionLifecycleState.isTerminal`) — this
/// never records a psychological judgement about *why*, only the optional
/// free-text [reason] the user themselves chose to supply.
class AbandonMissionUseCase {
  const AbandonMissionUseCase(this._repository);

  final MissionEventRepository _repository;

  Future<MissionAggregate> call({
    required MissionAggregate aggregate,
    required String userId,
    String? reason,
  }) async {
    if (!aggregate.canAbandon) {
      throw MissionLifecycleException(
        MissionTransitionFailure(
          reason: TransitionFailureReason.invalidTransition,
          message: "This mission can't be abandoned from its current state.",
          currentState: aggregate.lifecycleState,
          attemptedEvent: MissionEventType.abandoned,
        ),
      );
    }

    final now = DateTime.now().toUtc();
    final draft = MissionAbandoned(
      eventId: MissionEventIdGenerator.newEventId(),
      missionInstanceId: aggregate.instance.instanceId,
      userId: userId,
      occurredAt: now,
      clientCreatedAt: now,
      sequenceNumber: 0,
      source: MissionEventSource.userAction,
      idempotencyKey: MissionEventIdGenerator.singleton(
        aggregate.instance.instanceId,
        'abandoned',
      ),
      reason: reason,
    );
    return appendAndRehydrate(_repository, aggregate.instance, draft);
  }
}
