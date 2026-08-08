import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/data/local/in_memory_mission_event_repository.dart';
import 'package:forge/features/missions/domain/events/mission_event.dart';
import 'package:forge/features/missions/domain/events/mission_event_source.dart';
import 'package:forge/features/missions/domain/repositories/mission_event_repository.dart';

import '../../../support/mission_lifecycle_test_helpers.dart';

void main() {
  late InMemoryMissionEventRepository repository;
  const missionId = 'mission-1';

  setUp(() => repository = InMemoryMissionEventRepository());
  tearDown(() => repository.dispose());

  MissionAssigned draft({String idempotencyKey = 'assigned', DateTime? at}) {
    final time = at ?? DateTime.utc(2026, 8, 10, 9);
    return MissionAssigned(
      eventId: 'evt-$idempotencyKey-${time.microsecondsSinceEpoch}',
      missionInstanceId: missionId,
      userId: testUserId,
      occurredAt: time,
      clientCreatedAt: time,
      sequenceNumber: 0,
      source: MissionEventSource.system,
      idempotencyKey: idempotencyKey,
    );
  }

  test('append assigns sequence numbers starting at 1', () async {
    final first = await repository.append(draft(idempotencyKey: 'a'));
    final second = await repository.append(draft(idempotencyKey: 'b'));
    expect(first.sequenceNumber, 1);
    expect(second.sequenceNumber, 2);
  });

  test('appending a duplicate idempotency key throws', () async {
    await repository.append(draft(idempotencyKey: 'a'));
    expect(
      () => repository.append(draft(idempotencyKey: 'a')),
      throwsA(isA<MissionEventDuplicateException>()),
    );
  });

  test('a malformed draft (missing an identifier) throws', () async {
    final malformed = MissionAssigned(
      eventId: '',
      missionInstanceId: missionId,
      userId: testUserId,
      occurredAt: DateTime.utc(2026, 8, 10),
      clientCreatedAt: DateTime.utc(2026, 8, 10),
      sequenceNumber: 0,
      source: MissionEventSource.system,
      idempotencyKey: 'x',
    );
    expect(
      () => repository.append(malformed),
      throwsA(isA<MissionEventAppendException>()),
    );
  });

  test('occurredAt before the stream\'s first event is rejected', () async {
    await repository.append(
      draft(idempotencyKey: 'a', at: DateTime.utc(2026, 8, 10, 9)),
    );
    expect(
      () => repository.append(
        draft(idempotencyKey: 'b', at: DateTime.utc(2026, 8, 9)),
      ),
      throwsA(isA<MissionEventAppendException>()),
    );
  });

  test(
    'appendBatch is all-or-nothing: one bad draft rejects the whole batch',
    () async {
      final good = draft(idempotencyKey: 'a');
      final duplicate = draft(idempotencyKey: 'a');

      expect(
        () => repository.appendBatch([good, duplicate]),
        throwsA(isA<MissionEventDuplicateException>()),
      );
      expect(repository.eventsForMission(missionId), isEmpty);
    },
  );

  test('eventsForMission returns events sorted by append order', () async {
    await repository.append(draft(idempotencyKey: 'a'));
    await repository.append(draft(idempotencyKey: 'b'));
    final events = repository.eventsForMission(missionId);
    expect(events.map((e) => e.sequenceNumber), [1, 2]);
  });

  test('observeMissionEvents does not replay the current value to a new '
      'subscriber', () async {
    await repository.append(draft(idempotencyKey: 'a'));
    final events = <List<MissionEvent>>[];
    final sub = repository.observeMissionEvents(missionId).listen(events.add);
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);

    await repository.append(draft(idempotencyKey: 'b'));
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));
    expect(events.single, hasLength(2));

    await sub.cancel();
  });

  test(
    'sync queue tracking: queued -> confirmed removes it from pending',
    () async {
      final event = await repository.append(draft(idempotencyKey: 'a'));
      repository.markSyncQueued([event]);
      expect(repository.pendingSyncEvents(), hasLength(1));

      repository.markSyncConfirmed([event.eventId]);
      expect(repository.pendingSyncEvents(), isEmpty);
    },
  );

  test('sync queue tracking: a retryable failure stays pending', () async {
    final event = await repository.append(draft(idempotencyKey: 'a'));
    repository.markSyncQueued([event]);
    repository.markSyncFailed([event.eventId], errorCode: 'timeout');
    expect(repository.pendingSyncEvents(), hasLength(1));
    expect(repository.pendingSyncEvents().single.attemptCount, 1);
  });

  test(
    'sync queue tracking: a permanent failure is no longer pending',
    () async {
      final event = await repository.append(draft(idempotencyKey: 'a'));
      repository.markSyncQueued([event]);
      repository.markSyncFailed(
        [event.eventId],
        errorCode: 'rejected',
        permanent: true,
      );
      expect(repository.pendingSyncEvents(), isEmpty);
    },
  );
}
