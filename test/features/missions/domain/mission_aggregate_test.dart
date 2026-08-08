import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/aggregates/mission_aggregate.dart';
import 'package:forge/features/missions/domain/aggregates/mission_lifecycle_state.dart';
import 'package:forge/features/missions/domain/aggregates/mission_reward_state.dart';
import 'package:forge/features/missions/domain/events/mission_event.dart';
import 'package:forge/features/missions/domain/events/mission_event_source.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_state.dart';

import '../../../support/mission_lifecycle_test_helpers.dart';

DateTime _t(int minutes) =>
    DateTime.utc(2026, 8, 10, 9).add(Duration(minutes: minutes));

void main() {
  final instance = testMissionInstance();

  MissionAssigned assigned(int seq) => MissionAssigned(
    eventId: 'e$seq',
    missionInstanceId: instance.instanceId,
    userId: testUserId,
    occurredAt: _t(seq),
    clientCreatedAt: _t(seq),
    sequenceNumber: seq,
    source: MissionEventSource.system,
    idempotencyKey: 'assigned',
  );

  MissionAccepted accepted(int seq) => MissionAccepted(
    eventId: 'e$seq',
    missionInstanceId: instance.instanceId,
    userId: testUserId,
    occurredAt: _t(seq),
    clientCreatedAt: _t(seq),
    sequenceNumber: seq,
    source: testSource,
    idempotencyKey: 'accepted',
  );

  MissionStarted started(int seq) => MissionStarted(
    eventId: 'e$seq',
    missionInstanceId: instance.instanceId,
    userId: testUserId,
    occurredAt: _t(seq),
    clientCreatedAt: _t(seq),
    sequenceNumber: seq,
    source: testSource,
    idempotencyKey: 'started',
    sessionId: 'sess-1',
  );

  MissionSubmitted submitted(int seq) => MissionSubmitted(
    eventId: 'e$seq',
    missionInstanceId: instance.instanceId,
    userId: testUserId,
    occurredAt: _t(seq),
    clientCreatedAt: _t(seq),
    sequenceNumber: seq,
    source: testSource,
    idempotencyKey: 'submitted-$seq',
  );

  MissionCompleted completed(int seq) => MissionCompleted(
    eventId: 'e$seq',
    missionInstanceId: instance.instanceId,
    userId: testUserId,
    occurredAt: _t(seq),
    clientCreatedAt: _t(seq),
    sequenceNumber: seq,
    source: MissionEventSource.system,
    idempotencyKey: 'completed-$seq',
  );

  test('an empty event stream still reports lifecycle assigned', () {
    final aggregate = MissionAggregate.rehydrate(instance, const []);
    expect(aggregate.lifecycleState, MissionLifecycleState.assigned);
    expect(aggregate.canAccept, isTrue);
    expect(aggregate.rewardState, MissionRewardState.none);
  });

  test('assigned -> accepted -> active -> submitted -> completed advances '
      'correctly through the transition table', () {
    final aggregate = MissionAggregate.rehydrate(instance, [
      assigned(1),
      accepted(2),
      started(3),
      submitted(4),
      completed(5),
    ]);

    expect(aggregate.lifecycleState, MissionLifecycleState.completed);
    expect(aggregate.rewardState, MissionRewardState.pendingServerConfirmation);
    expect(aggregate.acceptedAt, _t(2));
    expect(aggregate.startedAt, _t(3));
    expect(aggregate.completedAt, _t(5));
    expect(aggregate.canUndoCompletion, isTrue);
  });

  test(
    'events are replayed in sequenceNumber order regardless of list order',
    () {
      final ordered = MissionAggregate.rehydrate(instance, [
        assigned(1),
        accepted(2),
        started(3),
      ]);
      final shuffled = MissionAggregate.rehydrate(instance, [
        started(3),
        assigned(1),
        accepted(2),
      ]);

      expect(shuffled.lifecycleState, ordered.lifecycleState);
      expect(shuffled.lifecycleState, MissionLifecycleState.active);
    },
  );

  test('an event that is illegal from the current state is skipped '
      'defensively rather than corrupting the aggregate', () {
    // `started` before `accepted` is not a legal transition (accepted ->
    // active only) — replay must skip it, not silently jump ahead.
    final aggregate = MissionAggregate.rehydrate(instance, [
      assigned(1),
      started(2),
    ]);
    expect(aggregate.lifecycleState, MissionLifecycleState.assigned);
  });

  test('completion can be undone, returning lifecycle to active', () {
    final withCompletion = MissionAggregate.rehydrate(instance, [
      assigned(1),
      accepted(2),
      started(3),
      submitted(4),
      completed(5),
    ]);
    expect(withCompletion.canUndoCompletion, isTrue);

    final undone = MissionAggregate.rehydrate(instance, [
      assigned(1),
      accepted(2),
      started(3),
      submitted(4),
      completed(5),
      MissionCompletionUndone(
        eventId: 'e6',
        missionInstanceId: instance.instanceId,
        userId: testUserId,
        occurredAt: _t(6),
        clientCreatedAt: _t(6),
        sequenceNumber: 6,
        source: testSource,
        idempotencyKey: 'undo',
      ),
    ]);

    expect(undone.lifecycleState, MissionLifecycleState.active);
    expect(undone.rewardState, MissionRewardState.none);
    expect(undone.completedAt, isNull);
    expect(undone.canSubmit, isTrue);
  });

  test(
    'a validation failure records reasons and stays open for resubmission',
    () {
      final aggregate = MissionAggregate.rehydrate(instance, [
        assigned(1),
        accepted(2),
        started(3),
        submitted(4),
        MissionValidationFailed(
          eventId: 'e5',
          missionInstanceId: instance.instanceId,
          userId: testUserId,
          occurredAt: _t(5),
          clientCreatedAt: _t(5),
          sequenceNumber: 5,
          source: MissionEventSource.localValidation,
          idempotencyKey: 'vf',
          reasonCodes: const ['binaryNotCompleted'],
          userFacingExplanation: 'Mark the mission as done to submit.',
        ),
      ]);

      expect(aggregate.lifecycleState, MissionLifecycleState.validationFailed);
      expect(aggregate.lastValidationFailureReasons, ['binaryNotCompleted']);
      expect(aggregate.canResume, isTrue);
    },
  );

  test('progress updates only apply while active or paused', () {
    const progress = CounterProgressState(currentCount: 3, targetCount: 10);
    final aggregate = MissionAggregate.rehydrate(instance, [
      assigned(1),
      accepted(2),
      started(3),
      MissionProgressUpdated(
        eventId: 'e4',
        missionInstanceId: instance.instanceId,
        userId: testUserId,
        occurredAt: _t(4),
        clientCreatedAt: _t(4),
        sequenceNumber: 4,
        source: testSource,
        idempotencyKey: 'p1',
        progress: progress,
      ),
    ]);

    expect(aggregate.progressState, isA<CounterProgressState>());
    expect((aggregate.progressState as CounterProgressState).currentCount, 3);
  });
}
