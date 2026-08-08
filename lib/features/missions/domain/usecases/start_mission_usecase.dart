import '../aggregates/mission_aggregate.dart';
import '../aggregates/mission_lifecycle_exception.dart';
import '../aggregates/mission_transition_failure.dart';
import '../events/mission_event.dart';
import '../events/mission_event_id_generator.dart';
import '../events/mission_event_source.dart';
import '../repositories/mission_event_repository.dart';
import '../sessions/mission_clock.dart';
import 'mission_event_append_helper.dart';

/// Opens the mission's one and only work session. `started` only ever
/// legally fires once per mission (see `MissionLifecycleTransitions`: a
/// completion-undo returns straight to `active`, never back through
/// `accepted`), so the fixed idempotency key is safe.
class StartMissionUseCase {
  const StartMissionUseCase(
    this._repository, {
    this._clock = const SystemMissionClock(),
  });

  final MissionEventRepository _repository;
  final MissionClock _clock;

  Future<MissionAggregate> call({
    required MissionAggregate aggregate,
    required String userId,
    String? clientSessionId,
  }) async {
    if (!aggregate.canStart) {
      throw MissionLifecycleException(
        MissionTransitionFailure(
          reason: TransitionFailureReason.invalidTransition,
          message: "This mission can't be started from its current state.",
          currentState: aggregate.lifecycleState,
          attemptedEvent: MissionEventType.started,
        ),
      );
    }

    final now = _clock.now();
    final draft = MissionStarted(
      eventId: MissionEventIdGenerator.newEventId(),
      missionInstanceId: aggregate.instance.instanceId,
      userId: userId,
      occurredAt: now,
      clientCreatedAt: now,
      sequenceNumber: 0,
      source: MissionEventSource.userAction,
      idempotencyKey: MissionEventIdGenerator.singleton(
        aggregate.instance.instanceId,
        'started',
      ),
      sessionId: MissionEventIdGenerator.newSessionId(),
      clientSessionId: clientSessionId,
    );
    return appendAndRehydrate(_repository, aggregate.instance, draft);
  }
}
