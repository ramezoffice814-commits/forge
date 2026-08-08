import '../aggregates/mission_aggregate.dart';
import '../entities/mission_instance.dart';
import '../events/mission_event.dart';
import '../repositories/mission_event_repository.dart';

/// Shared plumbing for every mission use case: append one draft event, then
/// rehydrate from the mission's full event log so the returned aggregate is
/// always derived the same way the repository's own stream would derive it.
Future<MissionAggregate> appendAndRehydrate(
  MissionEventRepository repository,
  MissionInstance instance,
  MissionEvent draft,
) async {
  await repository.append(draft);
  return MissionAggregate.rehydrate(
    instance,
    repository.eventsForMission(instance.instanceId),
  );
}
