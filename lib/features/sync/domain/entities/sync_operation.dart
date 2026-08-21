import 'package:flutter/foundation.dart';

import '../enums/sync_operation_status.dart';

/// One queued unit of work — [payload] is deliberately generic (usually a
/// `BackendCommand`, but this module stays decoupled from `core/backend`
/// so it could queue any idempotent, sequenced operation). Identity is
/// [idempotencyKey], not [operationId]: two [SyncOperation]s with the
/// same key are the same logical operation, retried.
@immutable
class SyncOperation<T> {
  const SyncOperation({
    required this.operationId,
    required this.idempotencyKey,
    required this.sequence,
    required this.payload,
    required this.status,
    required this.queuedAt,
    this.attemptCount = 0,
  });

  final String operationId;
  final String idempotencyKey;
  final int sequence;
  final T payload;
  final SyncOperationStatus status;
  final DateTime queuedAt;
  final int attemptCount;

  SyncOperation<T> copyWith({SyncOperationStatus? status, int? attemptCount}) {
    return SyncOperation<T>(
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      sequence: sequence,
      payload: payload,
      status: status ?? this.status,
      queuedAt: queuedAt,
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }
}
