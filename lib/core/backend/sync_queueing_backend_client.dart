import 'package:flutter/foundation.dart';

import '../../features/sync/domain/entities/sync_operation.dart';
import '../../features/sync/domain/entities/sync_queue.dart';
import '../../features/sync/domain/enums/sync_operation_status.dart';
import 'backend_client.dart';
import 'commands/accept_mission_command.dart';
import 'commands/backend_command.dart';
import 'commands/cancel_mission_command.dart';
import 'commands/record_mission_progress_command.dart';
import 'commands/start_mission_command.dart';
import 'commands/submit_mission_command.dart';
import 'raw_backend_response.dart';
import 'responses/mission_accepted_server_result.dart';
import 'responses/mission_progress_server_result.dart';
import 'responses/mission_submission_server_result.dart';
import 'supabase_backend_client.dart' show MalformedBackendResponseException;

/// Thrown by [SyncQueueingBackendClient] instead of letting the
/// underlying transport failure propagate opaquely — tells the caller
/// this command's outcome is not yet known, but it has been safely
/// queued (preserving its command id, idempotency key, and ordering) for
/// a later [SyncQueueingBackendClient.flushPending] call. The caller
/// must treat this exactly like any other "still provisional, not
/// server-confirmed" state — never as success.
@immutable
class CommandQueuedForSyncException implements Exception {
  const CommandQueuedForSyncException(this.command, this.cause);

  final BackendCommand command;
  final Object cause;

  @override
  String toString() =>
      'CommandQueuedForSyncException(${command.runtimeType} queued after: $cause)';
}

/// Minimal offline integration with the existing Phase 10A sync
/// foundation (`lib/features/sync/`) — deliberately not a background
/// daemon (spec section 23: "do not build a heavy sync daemon"). Wraps
/// any [BackendClient] (in practice, [SupabaseBackendClient]): a call
/// that fails to reach a real server outcome is queued as provisional
/// rather than lost, and only [flushPending] — called explicitly by
/// whatever the app's connectivity-recovery signal is — ever attempts to
/// turn a queued command into a real, server-confirmed result. Nothing
/// here ever marks a queued command "confirmed" without an actual
/// [BackendClient] response backing that decision, matching the spec's
/// "failed/conflicted sync must not silently appear confirmed."
class SyncQueueingBackendClient implements BackendClient {
  SyncQueueingBackendClient(this._client, this._queue);

  final BackendClient _client;
  final SyncQueue<BackendCommand> _queue;

  /// Read-only access for anything that needs to observe queue state
  /// without driving it — `SyncQueueExecutor`'s status derivation, the
  /// persistence layer's save-after-mutate calls, diagnostics.
  SyncQueue<BackendCommand> get queue => _queue;

  Future<T> _attempt<T>(
    BackendCommand command,
    Future<T> Function() call,
  ) async {
    try {
      return await call();
    } catch (cause) {
      _queue.enqueue(
        SyncOperation<BackendCommand>(
          operationId: command.commandId,
          idempotencyKey: command.idempotencyKey,
          sequence: command.sequence,
          payload: command,
          status: SyncOperationStatus.pending,
          queuedAt: command.timestamp,
        ),
      );
      throw CommandQueuedForSyncException(command, cause);
    }
  }

  @override
  Future<RawBackendResponse<MissionAcceptedServerResult>> acceptMission(
    AcceptMissionCommand command,
  ) => _attempt(command, () => _client.acceptMission(command));

  @override
  Future<RawBackendResponse<MissionAcceptedServerResult>> startMission(
    StartMissionCommand command,
  ) => _attempt(command, () => _client.startMission(command));

  @override
  Future<RawBackendResponse<MissionProgressServerResult>> recordProgress(
    RecordMissionProgressCommand command,
  ) => _attempt(command, () => _client.recordProgress(command));

  @override
  Future<RawBackendResponse<MissionSubmissionServerResult>> submitMission(
    SubmitMissionCommand command,
  ) => _attempt(command, () => _client.submitMission(command));

  @override
  Future<RawBackendResponse<void>> cancelMission(
    CancelMissionCommand command,
  ) => _attempt(command, () => _client.cancelMission(command));

  /// Attempts every pending queued command, in [SyncQueue.pendingInOrder]
  /// order, stopping at the first one that still fails (preserving
  /// ordering — spec section 7 — rather than racing later commands ahead
  /// of an earlier one that hasn't actually succeeded yet, and directly
  /// implementing "stop dependent commands after a conflict"). Each
  /// success is marked [SyncQueue.markConfirmed] only after a real
  /// [BackendClient] call actually returned a response.
  ///
  /// A failure is [SyncQueue.markConflict] (not auto-retried again by a
  /// later [flushPending] call — needs a user decision) when it's a
  /// [MalformedBackendResponseException] — an unrecognized/internal
  /// error is exactly the "automatic reconciliation is unsafe" case (see
  /// `MissionCommandReconciliation`'s matching [ReconciliationOutcome
  /// .conflict] classification). Anything else (a transport failure —
  /// timeout, connection loss, backend unreachable) is left `pending`
  /// (via [SyncQueue.markFailed]) so the *same* command, with its *same*
  /// idempotency key, is simply retried on the next flush — spec section
  /// 20: never mint a new idempotency key just because the network
  /// timed out.
  Future<void> flushPending() async {
    for (final operation in _queue.pendingInOrder) {
      _queue.markSyncing(operation.operationId);
      try {
        await _dispatch(operation.payload);
        _queue.markConfirmed(operation.operationId);
      } catch (cause) {
        if (cause is MalformedBackendResponseException) {
          _queue.markConflict(operation.operationId);
        } else {
          _queue.markFailed(operation.operationId);
        }
        return; // preserve ordering — don't let a later op jump ahead.
      }
    }
  }

  Future<void> _dispatch(BackendCommand command) {
    return switch (command) {
      AcceptMissionCommand() => _client.acceptMission(command),
      StartMissionCommand() => _client.startMission(command),
      RecordMissionProgressCommand() => _client.recordProgress(command),
      SubmitMissionCommand() => _client.submitMission(command),
      CancelMissionCommand() => _client.cancelMission(command),
      _ => throw StateError(
        'Unrecognized queued command type: ${command.runtimeType}',
      ),
    };
  }
}
