import '../aggregates/mission_aggregate.dart';
import '../aggregates/mission_lifecycle_exception.dart';
import '../aggregates/mission_transition_failure.dart';
import '../events/mission_event.dart';
import '../events/mission_event_id_generator.dart';
import '../events/mission_event_source.dart';
import '../repositories/mission_event_repository.dart';
import '../sessions/mission_clock.dart';
import 'mission_event_append_helper.dart';

class ResumeMissionUseCase {
  const ResumeMissionUseCase(
    this._repository, {
    this._clock = const SystemMissionClock(),
  });

  final MissionEventRepository _repository;
  final MissionClock _clock;

  Future<MissionAggregate> call({
    required MissionAggregate aggregate,
    required String userId,
  }) async {
    if (!aggregate.canResume) {
      throw MissionLifecycleException(
        MissionTransitionFailure(
          reason: TransitionFailureReason.invalidTransition,
          message: "This mission can't be resumed from its current state.",
          currentState: aggregate.lifecycleState,
          attemptedEvent: MissionEventType.resumed,
        ),
      );
    }

    final now = _clock.now();
    final draft = MissionResumed(
      eventId: MissionEventIdGenerator.newEventId(),
      missionInstanceId: aggregate.instance.instanceId,
      userId: userId,
      occurredAt: now,
      clientCreatedAt: now,
      sequenceNumber: 0,
      source: MissionEventSource.userAction,
      idempotencyKey: MissionEventIdGenerator.newEventId(),
    );
    return appendAndRehydrate(_repository, aggregate.instance, draft);
  }
}
