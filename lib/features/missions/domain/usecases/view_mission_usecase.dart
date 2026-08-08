import '../aggregates/mission_aggregate.dart';
import '../events/mission_event.dart';
import '../events/mission_event_id_generator.dart';
import '../events/mission_event_source.dart';
import '../repositories/mission_event_repository.dart';
import 'mission_event_append_helper.dart';

/// Records that the user opened the mission for the first time. A no-op
/// (not an error) once the mission has moved past `assigned` — opening the
/// page repeatedly should never fail or re-append the fact.
class ViewMissionUseCase {
  const ViewMissionUseCase(this._repository);

  final MissionEventRepository _repository;

  Future<MissionAggregate> call({
    required MissionAggregate aggregate,
    required String userId,
  }) async {
    if (!aggregate.canView) return aggregate;

    final now = DateTime.now().toUtc();
    final draft = MissionViewed(
      eventId: MissionEventIdGenerator.newEventId(),
      missionInstanceId: aggregate.instance.instanceId,
      userId: userId,
      occurredAt: now,
      clientCreatedAt: now,
      sequenceNumber: 0,
      source: MissionEventSource.userAction,
      idempotencyKey: MissionEventIdGenerator.singleton(
        aggregate.instance.instanceId,
        'viewed',
      ),
    );
    return appendAndRehydrate(_repository, aggregate.instance, draft);
  }
}
