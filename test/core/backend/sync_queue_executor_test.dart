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
import 'package:forge/core/backend/supabase_backend_client.dart';
import 'package:forge/core/backend/sync_queue_executor.dart';
import 'package:forge/core/backend/sync_queueing_backend_client.dart';
import 'package:forge/features/sync/domain/entities/sync_operation.dart';
import 'package:forge/features/sync/domain/entities/sync_queue.dart';
import 'package:forge/features/sync/domain/enums/sync_operation_status.dart';

/// A [BackendClient] whose `acceptMission` outcome is scripted per-call —
/// lets tests exercise "first fails (network), then succeeds",
/// "always malformed (conflict)", etc.
class ScriptedBackendClient implements BackendClient {
  ScriptedBackendClient(this._script);

  final List<Object?>
  _script; // null = network failure, Exception = throw, else success.
  int callCount = 0;

  @override
  Future<RawBackendResponse<MissionAcceptedServerResult>> acceptMission(
    AcceptMissionCommand command,
  ) async {
    final outcome = _script[callCount];
    callCount += 1;
    if (outcome is Exception) throw outcome;
    if (outcome == null) throw Exception('simulated network failure');
    final now = DateTime.utc(2026, 8, 19);
    return RawBackendResponse<MissionAcceptedServerResult>.fromBackendAdapter(
      payload: MissionAcceptedServerResult(
        status: ServerValidationStatus.accepted,
        missionInstanceId: command.missionInstanceId,
        serverTimestamp: now,
        confirmationId: 'confirm-${command.commandId}',
      ),
      serverTimestamp: now,
      confirmationId: 'confirm-${command.commandId}',
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

AcceptMissionCommand _acceptCommand({
  required String id,
  required int sequence,
  required DateTime now,
}) {
  return AcceptMissionCommand(
    commandId: id,
    missionInstanceId: 'mission-$id',
    userId: 'user-a',
    timestamp: now,
    sequence: sequence,
    idempotencyKey: 'key-$id',
  );
}

SyncOperation<BackendCommand> _operationFor(BackendCommand command) {
  return SyncOperation<BackendCommand>(
    operationId: command.commandId,
    idempotencyKey: command.idempotencyKey,
    sequence: command.sequence,
    payload: command,
    status: SyncOperationStatus.pending,
    queuedAt: command.timestamp,
  );
}

void main() {
  final now = DateTime.utc(2026, 8, 19, 12);

  test('runOnce reports idle once every queued command is confirmed', () async {
    final underlying = ScriptedBackendClient([true, true]);
    final queue = SyncQueue<BackendCommand>();
    final client = SyncQueueingBackendClient(underlying, queue);
    final executor = SyncQueueExecutor(client);

    queue.enqueue(
      _operationFor(_acceptCommand(id: 'a', sequence: 1, now: now)),
    );
    queue.enqueue(
      _operationFor(_acceptCommand(id: 'b', sequence: 2, now: now)),
    );

    final snapshot = await executor.runOnce();

    expect(snapshot.status, SyncExecutorStatus.idle);
    expect(snapshot.pendingCount, 0);
  });

  test(
    'a network failure leaves the command pending (retryable), not conflicted',
    () async {
      final underlying = ScriptedBackendClient([null]);
      final queue = SyncQueue<BackendCommand>();
      final client = SyncQueueingBackendClient(underlying, queue);
      final executor = SyncQueueExecutor(client);

      queue.enqueue(
        _operationFor(_acceptCommand(id: 'a', sequence: 1, now: now)),
      );

      final snapshot = await executor.runOnce();

      expect(snapshot.status, SyncExecutorStatus.pendingRetry);
      expect(snapshot.pendingCount, 1);
      expect(snapshot.conflictCount, 0);
    },
  );

  test(
    'a malformed/unrecognized response marks the command conflict, not pending',
    () async {
      final underlying = ScriptedBackendClient([
        const MalformedBackendResponseException('unexpected shape'),
      ]);
      final queue = SyncQueue<BackendCommand>();
      final client = SyncQueueingBackendClient(underlying, queue);
      final executor = SyncQueueExecutor(client);

      queue.enqueue(
        _operationFor(_acceptCommand(id: 'a', sequence: 1, now: now)),
      );

      final snapshot = await executor.runOnce();

      expect(snapshot.status, SyncExecutorStatus.conflict);
      expect(snapshot.conflictCount, 1);
    },
  );

  test(
    'dependency blocking: a later command is never attempted after an earlier one fails',
    () async {
      final underlying = ScriptedBackendClient([null, true]);
      final queue = SyncQueue<BackendCommand>();
      final client = SyncQueueingBackendClient(underlying, queue);
      final executor = SyncQueueExecutor(client);

      queue.enqueue(
        _operationFor(_acceptCommand(id: 'a', sequence: 1, now: now)),
      );
      queue.enqueue(
        _operationFor(_acceptCommand(id: 'b', sequence: 2, now: now)),
      );

      await executor.runOnce();

      // Only the first (failing) command was ever attempted — 'b' is
      // still pending too (never touched), but never actually dispatched.
      expect(underlying.callCount, 1);
      expect(queue.pendingInOrder, hasLength(2));
      expect(queue.pendingInOrder.first.operationId, 'a');
      expect(queue.pendingInOrder.first.status, SyncOperationStatus.pending);
    },
  );

  test(
    'a conflicted command is never auto-retried on a subsequent runOnce',
    () async {
      final underlying = ScriptedBackendClient([
        const MalformedBackendResponseException('unexpected shape'),
        true, // would succeed if ever retried — it must not be.
      ]);
      final queue = SyncQueue<BackendCommand>();
      final client = SyncQueueingBackendClient(underlying, queue);
      final executor = SyncQueueExecutor(client);

      queue.enqueue(
        _operationFor(_acceptCommand(id: 'a', sequence: 1, now: now)),
      );
      await executor.runOnce();
      expect(underlying.callCount, 1);

      final second = await executor.runOnce();
      expect(second.status, SyncExecutorStatus.conflict);
      expect(underlying.callCount, 1); // never re-attempted.
    },
  );

  test('backoffFor grows and is capped at maxBackoff', () {
    final executor = SyncQueueExecutor(
      SyncQueueingBackendClient(
        ScriptedBackendClient(const []),
        SyncQueue<BackendCommand>(),
      ),
      baseBackoff: const Duration(seconds: 1),
      maxBackoff: const Duration(seconds: 10),
    );

    expect(executor.backoffFor(0), const Duration(seconds: 1));
    expect(executor.backoffFor(1), const Duration(seconds: 2));
    expect(executor.backoffFor(10), const Duration(seconds: 10)); // capped.
  });
}
