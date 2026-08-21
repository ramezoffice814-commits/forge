import '../aggregates/mission_aggregate.dart';
import '../entities/mission_instance.dart';
import '../events/mission_event.dart';
import '../events/mission_event_id_generator.dart';
import '../events/mission_event_source.dart';
import '../repositories/mission_event_repository.dart';
import '../sessions/mission_clock.dart';

/// Ensures exactly one `MissionAssigned` event exists for a freshly-derived
/// [MissionInstance] — safe to call every time the instance is (re)computed,
/// since the fixed idempotency key makes a second attempt a harmless no-op.
class AssignMissionUseCase {
  const AssignMissionUseCase(
    this._repository, {
    this._clock = const SystemMissionClock(),
  });

  final MissionEventRepository _repository;
  final MissionClock _clock;

  Future<MissionAggregate> call({
    required MissionInstance instance,
    required String userId,
  }) async {
    final existing = _repository.eventsForMission(instance.instanceId);
    if (existing.isNotEmpty) {
      return MissionAggregate.rehydrate(instance, existing);
    }

    final now = _clock.now();
    final draft = MissionAssigned(
      eventId: MissionEventIdGenerator.newEventId(),
      missionInstanceId: instance.instanceId,
      userId: userId,
      occurredAt: now,
      clientCreatedAt: now,
      sequenceNumber: 0,
      source: MissionEventSource.system,
      idempotencyKey: MissionEventIdGenerator.singleton(
        instance.instanceId,
        'assigned',
      ),
    );

    try {
      await _repository.append(draft);
    } on MissionEventDuplicateException {
      // A concurrent caller already assigned it — the mission stream
      // already reflects the fact this call was trying to record.
    }

    return MissionAggregate.rehydrate(
      instance,
      _repository.eventsForMission(instance.instanceId),
    );
  }
}
