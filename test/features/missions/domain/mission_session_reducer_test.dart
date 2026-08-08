import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/events/mission_event.dart';
import 'package:forge/features/missions/domain/sessions/mission_session_reducer.dart';

import '../../../support/mission_lifecycle_test_helpers.dart';

void main() {
  const missionId = 'mission-1';
  final base = DateTime.utc(2026, 8, 10, 9);

  MissionStarted started(int seq, DateTime at) => MissionStarted(
    eventId: 'e$seq',
    missionInstanceId: missionId,
    userId: testUserId,
    occurredAt: at,
    clientCreatedAt: at,
    sequenceNumber: seq,
    source: testSource,
    idempotencyKey: 'started',
    sessionId: 'sess-1',
  );

  MissionPaused paused(int seq, DateTime at) => MissionPaused(
    eventId: 'e$seq',
    missionInstanceId: missionId,
    userId: testUserId,
    occurredAt: at,
    clientCreatedAt: at,
    sequenceNumber: seq,
    source: testSource,
    idempotencyKey: 'p$seq',
  );

  MissionResumed resumed(int seq, DateTime at) => MissionResumed(
    eventId: 'e$seq',
    missionInstanceId: missionId,
    userId: testUserId,
    occurredAt: at,
    clientCreatedAt: at,
    sequenceNumber: seq,
    source: testSource,
    idempotencyKey: 'r$seq',
  );

  MissionSubmitted submitted(int seq, DateTime at) => MissionSubmitted(
    eventId: 'e$seq',
    missionInstanceId: missionId,
    userId: testUserId,
    occurredAt: at,
    clientCreatedAt: at,
    sequenceNumber: seq,
    source: testSource,
    idempotencyKey: 's$seq',
  );

  test('a simple start -> submit interval counts as active time', () {
    final reduction = MissionSessionReducer.reduce([
      started(1, base),
      submitted(2, base.add(const Duration(minutes: 10))),
    ]);
    expect(reduction.totalActiveDuration, const Duration(minutes: 10));
    expect(reduction.totalPausedDuration, Duration.zero);
    expect(reduction.currentSession, isNull);
    expect(reduction.sessionHistory, hasLength(1));
  });

  test('pause/resume splits active and paused time correctly', () {
    final reduction = MissionSessionReducer.reduce([
      started(1, base),
      paused(2, base.add(const Duration(minutes: 5))),
      resumed(3, base.add(const Duration(minutes: 15))),
      submitted(4, base.add(const Duration(minutes: 20))),
    ]);
    // Active: 0-5min and 15-20min = 10 minutes. Paused: 5-15min = 10 minutes.
    expect(reduction.totalActiveDuration, const Duration(minutes: 10));
    expect(reduction.totalPausedDuration, const Duration(minutes: 10));
  });

  test(
    'a session left open (no closing event) is reported as currentSession',
    () {
      final reduction = MissionSessionReducer.reduce([
        started(1, base),
        paused(2, base.add(const Duration(minutes: 5))),
      ]);
      expect(reduction.currentSession, isNotNull);
      expect(reduction.currentSession!.isPaused, isTrue);
      expect(reduction.sessionHistory, isEmpty);
    },
  );

  test('an interval longer than the max trusted duration is capped, not '
      'trusted outright', () {
    final reduction = MissionSessionReducer.reduce([
      started(1, base),
      // A 30-hour gap — e.g. the device was asleep/offline.
      submitted(2, base.add(const Duration(hours: 30))),
    ]);
    expect(reduction.totalActiveDuration, const Duration(hours: 3));
  });
}
