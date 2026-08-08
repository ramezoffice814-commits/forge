import '../aggregates/mission_aggregate.dart';
import '../aggregates/mission_lifecycle_exception.dart';
import '../aggregates/mission_transition_failure.dart';
import '../events/mission_event.dart';
import '../events/mission_event_id_generator.dart';
import '../events/mission_event_source.dart';
import '../repositories/mission_event_repository.dart';
import '../sessions/mission_clock.dart';
import '../validation/mission_completion_validator.dart';

/// Drives the full submission flow (spec section 12): `Submitted` is always
/// appended first as the factual record of the attempt, then local
/// validation appends either `ValidationFailed` (mission stays open, user
/// can keep working) or `ValidationPassed` immediately followed by
/// `Completed`. Every outcome here is provisional — see
/// `MissionCompletionValidator` and `MissionRewardState` for why nothing
/// here ever grants a real reward.
class SubmitMissionUseCase {
  const SubmitMissionUseCase(
    this._repository, {
    this._clock = const SystemMissionClock(),
  });

  final MissionEventRepository _repository;
  final MissionClock _clock;

  Future<MissionAggregate> call({
    required MissionAggregate aggregate,
    required String userId,
  }) async {
    if (!aggregate.canSubmit) {
      throw MissionLifecycleException(
        MissionTransitionFailure(
          reason: TransitionFailureReason.invalidTransition,
          message: "This mission can't be submitted from its current state.",
          currentState: aggregate.lifecycleState,
          attemptedEvent: MissionEventType.submitted,
        ),
      );
    }

    final instance = aggregate.instance;
    final submittedAt = _clock.now();
    await _repository.append(
      MissionSubmitted(
        eventId: MissionEventIdGenerator.newEventId(),
        missionInstanceId: instance.instanceId,
        userId: userId,
        occurredAt: submittedAt,
        clientCreatedAt: submittedAt,
        sequenceNumber: 0,
        source: MissionEventSource.userAction,
        idempotencyKey: MissionEventIdGenerator.newEventId(),
      ),
    );

    final validation = MissionCompletionValidator.validate(
      aggregate.progressState,
    );
    final validatedAt = _clock.now();

    if (!validation.passed) {
      await _repository.append(
        MissionValidationFailed(
          eventId: MissionEventIdGenerator.newEventId(),
          missionInstanceId: instance.instanceId,
          userId: userId,
          occurredAt: validatedAt,
          clientCreatedAt: validatedAt,
          sequenceNumber: 0,
          source: MissionEventSource.localValidation,
          idempotencyKey: MissionEventIdGenerator.newEventId(),
          reasonCodes: validation.reasonCodes,
          userFacingExplanation: validation.userFacingExplanation,
        ),
      );
      return MissionAggregate.rehydrate(
        instance,
        _repository.eventsForMission(instance.instanceId),
      );
    }

    await _repository.append(
      MissionValidationPassed(
        eventId: MissionEventIdGenerator.newEventId(),
        missionInstanceId: instance.instanceId,
        userId: userId,
        occurredAt: validatedAt,
        clientCreatedAt: validatedAt,
        sequenceNumber: 0,
        source: MissionEventSource.localValidation,
        idempotencyKey: MissionEventIdGenerator.newEventId(),
      ),
    );

    final completedAt = _clock.now();
    await _repository.append(
      MissionCompleted(
        eventId: MissionEventIdGenerator.newEventId(),
        missionInstanceId: instance.instanceId,
        userId: userId,
        occurredAt: completedAt,
        clientCreatedAt: completedAt,
        sequenceNumber: 0,
        source: MissionEventSource.system,
        idempotencyKey: MissionEventIdGenerator.newEventId(),
      ),
    );

    return MissionAggregate.rehydrate(
      instance,
      _repository.eventsForMission(instance.instanceId),
    );
  }
}
