import 'dart:convert';

import '../storage/secure_key_value_store.dart';
import 'commands/accept_mission_command.dart';
import 'commands/backend_command.dart';
import 'commands/cancel_mission_command.dart';
import 'commands/record_mission_progress_command.dart';
import 'commands/start_mission_command.dart';
import 'commands/submit_mission_command.dart';
import '../../features/sync/domain/entities/sync_operation.dart';
import '../../features/sync/domain/enums/sync_operation_status.dart';

/// Minimum persistent storage for the mission sync queue (spec section
/// 21) — queued commands, their ids/idempotency keys, and (via the
/// per-user storage key itself) the owning user. Reuses the existing
/// [SecureKeyValueStore] (already used for the persisted auth session)
/// rather than introducing a new persistence package; nothing here is a
/// general-purpose database, just JSON-encode/decode of the one list a
/// [SyncQueue] already holds in memory.
///
/// Partitioned by user id at the storage-key level
/// (`forge.sync_queue.<userId>`) — this is what makes account-switch
/// queue isolation (spec sections 17/18) structurally true rather than
/// merely policy: User B's [load] call can only ever read a key User A
/// never wrote to, and [SyncQueueRestoreGuard.restorable] double-checks
/// each restored command's own `userId` field matches the caller
/// regardless.
class PersistedSyncQueueStore {
  const PersistedSyncQueueStore(this._store);

  final SecureKeyValueStore _store;

  String _keyFor(String userId) => 'forge.sync_queue.$userId';

  Future<List<SyncOperation<BackendCommand>>> load(String userId) async {
    final raw = await _store.read(_keyFor(userId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => _operationFromJson(e as Map<String, dynamic>))
          .whereType<SyncOperation<BackendCommand>>()
          .toList();
    } catch (_) {
      // Corrupt or unrecognized persisted data must never crash startup
      // (spec section 8: "do not block entire app indefinitely") —
      // treated as an empty queue rather than propagated.
      return const [];
    }
  }

  Future<void> save(
    String userId,
    List<SyncOperation<BackendCommand>> operations,
  ) async {
    final encoded = jsonEncode(
      operations.map(_operationToJson).toList(growable: false),
    );
    await _store.write(_keyFor(userId), encoded);
  }

  Future<void> clear(String userId) => _store.delete(_keyFor(userId));

  Map<String, Object?> _operationToJson(SyncOperation<BackendCommand> op) {
    return {
      'operationId': op.operationId,
      'idempotencyKey': op.idempotencyKey,
      'sequence': op.sequence,
      'status': op.status.name,
      'queuedAt': op.queuedAt.toIso8601String(),
      'attemptCount': op.attemptCount,
      'command': _commandToJson(op.payload),
    };
  }

  SyncOperation<BackendCommand>? _operationFromJson(Map<String, dynamic> json) {
    final command = _commandFromJson(json['command'] as Map<String, dynamic>);
    if (command == null) return null;
    return SyncOperation<BackendCommand>(
      operationId: json['operationId'] as String,
      idempotencyKey: json['idempotencyKey'] as String,
      sequence: json['sequence'] as int,
      payload: command,
      status: SyncOperationStatus.values.byName(json['status'] as String),
      queuedAt: DateTime.parse(json['queuedAt'] as String),
      attemptCount: json['attemptCount'] as int? ?? 0,
    );
  }

  Map<String, Object?> _commandToJson(BackendCommand command) {
    final base = {
      'commandId': command.commandId,
      'missionInstanceId': command.missionInstanceId,
      'userId': command.userId,
      'timestamp': command.timestamp.toIso8601String(),
      'sequence': command.sequence,
      'idempotencyKey': command.idempotencyKey,
    };
    return switch (command) {
      AcceptMissionCommand() => {...base, 'type': 'accept'},
      StartMissionCommand() => {...base, 'type': 'start'},
      RecordMissionProgressCommand(:final progressPayload) => {
        ...base,
        'type': 'progress',
        'payload': progressPayload,
      },
      SubmitMissionCommand(:final completionPayload) => {
        ...base,
        'type': 'submit',
        'payload': completionPayload,
      },
      CancelMissionCommand(:final reason) => {
        ...base,
        'type': 'cancel',
        'reason': reason,
      },
      _ => {...base, 'type': 'unknown'},
    };
  }

  BackendCommand? _commandFromJson(Map<String, dynamic> json) {
    final commandId = json['commandId'] as String;
    final missionInstanceId = json['missionInstanceId'] as String;
    final userId = json['userId'] as String;
    final timestamp = DateTime.parse(json['timestamp'] as String);
    final sequence = json['sequence'] as int;
    final idempotencyKey = json['idempotencyKey'] as String;

    switch (json['type'] as String?) {
      case 'accept':
        return AcceptMissionCommand(
          commandId: commandId,
          missionInstanceId: missionInstanceId,
          userId: userId,
          timestamp: timestamp,
          sequence: sequence,
          idempotencyKey: idempotencyKey,
        );
      case 'start':
        return StartMissionCommand(
          commandId: commandId,
          missionInstanceId: missionInstanceId,
          userId: userId,
          timestamp: timestamp,
          sequence: sequence,
          idempotencyKey: idempotencyKey,
        );
      case 'progress':
        return RecordMissionProgressCommand(
          commandId: commandId,
          missionInstanceId: missionInstanceId,
          userId: userId,
          timestamp: timestamp,
          sequence: sequence,
          idempotencyKey: idempotencyKey,
          progressPayload: (json['payload'] as Map).cast<String, Object?>(),
        );
      case 'submit':
        return SubmitMissionCommand(
          commandId: commandId,
          missionInstanceId: missionInstanceId,
          userId: userId,
          timestamp: timestamp,
          sequence: sequence,
          idempotencyKey: idempotencyKey,
          completionPayload: (json['payload'] as Map).cast<String, Object?>(),
        );
      case 'cancel':
        return CancelMissionCommand(
          commandId: commandId,
          missionInstanceId: missionInstanceId,
          userId: userId,
          timestamp: timestamp,
          sequence: sequence,
          idempotencyKey: idempotencyKey,
          reason: json['reason'] as String?,
        );
      default:
        return null; // unknown/future command type — dropped, not crashed on.
    }
  }
}

/// Defense-in-depth for spec section 18 ("Add explicit user ownership
/// checks to restored sync items"): even though [PersistedSyncQueueStore]
/// already partitions by storage key per user, this filter is the second,
/// independent check applied at restore time — a command whose own
/// `userId` doesn't match the caller is never re-enqueued, regardless of
/// which key it was read from.
abstract final class SyncQueueRestoreGuard {
  static List<SyncOperation<BackendCommand>> restorable(
    List<SyncOperation<BackendCommand>> loaded,
    String currentUserId,
  ) {
    return loaded
        .where((op) => op.payload.userId == currentUserId)
        .toList(growable: false);
  }
}
