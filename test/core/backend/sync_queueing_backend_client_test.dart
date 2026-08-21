import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/backend_client.dart';
import 'package:forge/core/backend/commands/accept_mission_command.dart';
import 'package:forge/core/backend/commands/backend_command.dart';
import 'package:forge/core/backend/commands/cancel_mission_command.dart';
import 'package:forge/core/backend/commands/record_mission_progress_command.dart';
import 'package:forge/core/backend/commands/start_mission_command.dart';
import 'package:forge/core/backend/commands/submit_mission_command.dart';
import 'package:forge/core/backend/raw_backend_response.dart';
import 'package:forge/core/backend/responses/mission_accepted_server_result.dart';
import 'package:forge/core/backend/responses/mission_progress_server_result.dart';
import 'package:forge/core/backend/responses/mission_submission_server_result.dart';
import 'package:forge/core/backend/responses/server_validation_status.dart';
import 'package:forge/core/backend/sync_queueing_backend_client.dart';
import 'package:forge/features/sync/domain/entities/sync_queue.dart';

import '../../support/backend_test_helpers.dart';

/// A [BackendClient] whose behavior for `acceptMission` can be flipped
/// between "always throws" and "always succeeds" mid-test, to simulate
/// connectivity coming back.
class FlakyBackendClient implements BackendClient {
  bool shouldFail = true;
  int acceptCallCount = 0;

  @override
  Future<RawBackendResponse<MissionAcceptedServerResult>> acceptMission(
    AcceptMissionCommand command,
  ) async {
    acceptCallCount += 1;
    if (shouldFail) {
      throw Exception('simulated network failure');
    }
    final now = DateTime.utc(2026, 8, 17, 12);
    return RawBackendResponse<MissionAcceptedServerResult>.fromBackendAdapter(
      payload: MissionAcceptedServerResult(
        status: ServerValidationStatus.accepted,
        missionInstanceId: command.missionInstanceId,
        serverTimestamp: now,
        confirmationId: 'confirm',
      ),
      serverTimestamp: now,
      confirmationId: 'confirm',
    );
  }

  @override
  Future<RawBackendResponse<MissionAcceptedServerResult>> startMission(
    StartMissionCommand command,
  ) => throw UnimplementedError();

  @override
  Future<RawBackendResponse<MissionProgressServerResult>> recordProgress(
    RecordMissionProgressCommand command,
  ) => throw UnimplementedError();

  @override
  Future<RawBackendResponse<MissionSubmissionServerResult>> submitMission(
    SubmitMissionCommand command,
  ) => throw UnimplementedError();

  @override
  Future<RawBackendResponse<void>> cancelMission(
    CancelMissionCommand command,
  ) => throw UnimplementedError();
}

void main() {
  final now = DateTime.utc(2026, 8, 17, 12);

  test(
    'a failed call is queued as provisional, never silently confirmed',
    () async {
      final underlying = FlakyBackendClient()..shouldFail = true;
      final queue = SyncQueue<BackendCommand>();
      final client = SyncQueueingBackendClient(underlying, queue);

      await expectLater(
        client.acceptMission(testAcceptCommand(timestamp: now)),
        throwsA(isA<CommandQueuedForSyncException>()),
      );

      expect(queue.pendingInOrder, hasLength(1));
      expect(queue.pendingInOrder.single.idempotencyKey, isNotEmpty);
    },
  );

  test(
    'flushPending confirms a queued command once the underlying client succeeds',
    () async {
      final underlying = FlakyBackendClient()..shouldFail = true;
      final queue = SyncQueue<BackendCommand>();
      final client = SyncQueueingBackendClient(underlying, queue);

      await expectLater(
        client.acceptMission(testAcceptCommand(timestamp: now)),
        throwsA(isA<CommandQueuedForSyncException>()),
      );
      expect(queue.pendingInOrder, hasLength(1));

      underlying.shouldFail = false;
      await client.flushPending();

      expect(queue.pendingInOrder, isEmpty);
      expect(
        underlying.acceptCallCount,
        2,
      ); // 1 failed attempt + 1 flush attempt.
    },
  );

  test(
    'flushPending leaves a still-failing command pending, not confirmed',
    () async {
      final underlying = FlakyBackendClient()..shouldFail = true;
      final queue = SyncQueue<BackendCommand>();
      final client = SyncQueueingBackendClient(underlying, queue);

      await expectLater(
        client.acceptMission(testAcceptCommand(timestamp: now)),
        throwsA(isA<CommandQueuedForSyncException>()),
      );

      await client.flushPending(); // underlying still fails.

      expect(queue.pendingInOrder, hasLength(1));
    },
  );
}
