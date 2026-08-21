import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/idempotency_replay_guard.dart';

void main() {
  test('a fresh command at sequence 1 is accepted', () {
    final guard = IdempotencyReplayGuard();
    final result = guard.evaluate(
      missionInstanceId: 'm1',
      idempotencyKey: 'm1:accept:1',
      sequence: 1,
    );
    expect(result, CommandAcceptance.accepted);
  });

  test('the same idempotency key retried is a duplicateRetry, not '
      'reprocessed', () {
    final guard = IdempotencyReplayGuard();
    guard.evaluate(
      missionInstanceId: 'm1',
      idempotencyKey: 'm1:accept:1',
      sequence: 1,
    );
    guard.recordAccepted(
      missionInstanceId: 'm1',
      idempotencyKey: 'm1:accept:1',
      sequence: 1,
      result: 'first-result',
    );

    final retry = guard.evaluate(
      missionInstanceId: 'm1',
      idempotencyKey: 'm1:accept:1',
      sequence: 1,
    );
    expect(retry, CommandAcceptance.duplicateRetry);
    expect(guard.cachedResultFor('m1:accept:1'), 'first-result');
  });

  test('a stale sequence (already superseded) is rejected', () {
    final guard = IdempotencyReplayGuard();
    guard.recordAccepted(
      missionInstanceId: 'm1',
      idempotencyKey: 'm1:accept:1',
      sequence: 1,
      result: 'r1',
    );
    guard.recordAccepted(
      missionInstanceId: 'm1',
      idempotencyKey: 'm1:start:2',
      sequence: 2,
      result: 'r2',
    );

    // A different idempotency key claiming an already-superseded sequence
    // is a replay attempt, not a legitimate retry.
    final result = guard.evaluate(
      missionInstanceId: 'm1',
      idempotencyKey: 'm1:submit:1',
      sequence: 1,
    );
    expect(result, CommandAcceptance.staleSequence);
  });

  test('a sequence that skips ahead is out-of-order and rejected', () {
    final guard = IdempotencyReplayGuard();
    guard.recordAccepted(
      missionInstanceId: 'm1',
      idempotencyKey: 'm1:accept:1',
      sequence: 1,
      result: 'r1',
    );

    // Sequence 4 arrives while only sequence 1 has been accepted — 2 and
    // 3 are missing.
    final result = guard.evaluate(
      missionInstanceId: 'm1',
      idempotencyKey: 'm1:submit:4',
      sequence: 4,
    );
    expect(result, CommandAcceptance.outOfOrder);
  });

  test('sequences for different missions are tracked independently', () {
    final guard = IdempotencyReplayGuard();
    guard.recordAccepted(
      missionInstanceId: 'm1',
      idempotencyKey: 'm1:accept:1',
      sequence: 1,
      result: 'r1',
    );

    final result = guard.evaluate(
      missionInstanceId: 'm2',
      idempotencyKey: 'm2:accept:1',
      sequence: 1,
    );
    expect(result, CommandAcceptance.accepted);
  });

  test('lastAcceptedSequenceFor defaults to 0 for an unseen mission', () {
    final guard = IdempotencyReplayGuard();
    expect(guard.lastAcceptedSequenceFor('never-seen'), 0);
  });
}
