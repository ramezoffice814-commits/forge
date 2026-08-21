import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/commands/submit_mission_command.dart';
import 'package:forge/core/backend/mock_backend_client.dart';
import 'package:forge/core/backend/responses/server_validation_status.dart';
import 'package:forge/core/backend/server_clock.dart';
import 'package:forge/core/security/authoritative_value.dart';

import '../../support/backend_test_helpers.dart';

void main() {
  final clock = MockServerClock(DateTime.utc(2026, 8, 10));

  MockBackendClient buildClient() => MockBackendClient(clock: clock);

  test('a normal accept -> start -> progress -> submit sequence is fully '
      'accepted', () async {
    final client = buildClient();
    final now = clock.now();

    final accept = await client.acceptMission(
      testAcceptCommand(timestamp: now, sequence: 1),
    );
    expect(accept.payload.status, ServerValidationStatus.accepted);

    final progress = await client.recordProgress(
      testProgressCommand(timestamp: now, sequence: 2),
    );
    expect(progress.payload.status, ServerValidationStatus.accepted);

    final submit = await client.submitMission(
      testSubmitCommand(timestamp: now, sequence: 3),
    );
    expect(submit.payload.status, ServerValidationStatus.accepted);
    expect(submit.payload.confirmedXpReward, isA<ServerConfirmedValue<int>>());
  });

  test('duplicate submission: retrying the exact same submit command '
      'returns the same cached result, never a second reward', () async {
    final client = buildClient();
    final now = clock.now();
    final command = testSubmitCommand(timestamp: now, sequence: 1);

    final first = await client.submitMission(command);
    final second = await client.submitMission(command); // same idempotencyKey

    expect(first.confirmationId, second.confirmationId);
    expect(
      first.payload.confirmedXpReward.value,
      second.payload.confirmedXpReward.value,
    );
    expect(identical(first, second), isTrue);
  });

  test('duplicate progress command: retrying the same progress command '
      'does not advance state twice', () async {
    final client = buildClient();
    final now = clock.now();
    final command = testProgressCommand(timestamp: now, sequence: 1);

    final first = await client.recordProgress(command);
    final second = await client.recordProgress(command);

    expect(first.payload.acceptedSequence, second.payload.acceptedSequence);
    expect(identical(first, second), isTrue);
  });

  test('out-of-order sequence is rejected, not silently accepted', () async {
    final client = buildClient();
    final now = clock.now();

    await client.acceptMission(testAcceptCommand(timestamp: now, sequence: 1));
    // Sequence 5 skips ahead — 2, 3, 4 were never sent.
    final response = await client.submitMission(
      testSubmitCommand(timestamp: now, sequence: 5),
    );

    expect(response.payload.status, ServerValidationStatus.rejected);
    expect(response.payload.reasons.single, contains('Out-of-order'));
  });

  test('a stale version (already-superseded sequence) is rejected', () async {
    final client = buildClient();
    final now = clock.now();

    await client.acceptMission(testAcceptCommand(timestamp: now, sequence: 1));
    await client.recordProgress(
      testProgressCommand(timestamp: now, sequence: 2),
    );

    // A new, different command replaying an already-superseded sequence.
    final stale = SubmitMissionCommand(
      commandId: 'cmd-stale',
      missionInstanceId: testMissionInstanceId,
      userId: testBackendUserId,
      timestamp: now,
      sequence: 1,
      idempotencyKey: 'replayed-key-not-seen-before',
      completionPayload: const {},
    );
    final response = await client.submitMission(stale);

    expect(response.payload.status, ServerValidationStatus.rejected);
    expect(response.payload.reasons.single, contains('Stale sequence'));
  });

  test('same command retry: a legitimate retry with the same idempotency '
      'key never duplicates the accepted-sequence advancement', () async {
    final client = buildClient();
    final now = clock.now();
    final command = testAcceptCommand(timestamp: now, sequence: 1);

    await client.acceptMission(command);
    await client.acceptMission(command);
    await client.acceptMission(command);

    // The mission's sequence should have advanced exactly once, not
    // three times — proven by a legitimate next command at sequence 2
    // being accepted (it would be rejected as out-of-order if the guard
    // had advanced past 1 on every retry).
    final next = await client.recordProgress(
      testProgressCommand(timestamp: now, sequence: 2),
    );
    expect(next.payload.status, ServerValidationStatus.accepted);
  });
}
