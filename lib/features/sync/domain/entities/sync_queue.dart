import '../enums/sync_operation_status.dart';
import 'sync_operation.dart';

/// A lightweight, in-memory sync queue — deliberately not a background
/// service (spec section 7: "do not create a heavy background service
/// yet"). A future worker can poll [pendingInOrder] and drive operations
/// through [markSyncing]/[markConfirmed]/[markFailed]/[markConflict]; this
/// class only owns ordering and state, never scheduling or network I/O.
class SyncQueue<T> {
  final List<SyncOperation<T>> _operations = [];
  final Set<String> _idempotencyKeysSeen = {};

  /// Returns `true` if actually enqueued, `false` if this
  /// [SyncOperation.idempotencyKey] was already queued before — enqueue
  /// itself is idempotent, so calling it twice for the same logical
  /// operation (e.g. a screen re-mounting and re-submitting the same
  /// local draft) never queues a duplicate.
  bool enqueue(SyncOperation<T> operation) {
    if (_idempotencyKeysSeen.contains(operation.idempotencyKey)) return false;
    _idempotencyKeysSeen.add(operation.idempotencyKey);
    _operations.add(operation);
    return true;
  }

  List<SyncOperation<T>> get all => List.unmodifiable(_operations);

  /// Deterministic ordering: by [SyncOperation.sequence] first, with
  /// [SyncOperation.queuedAt] then [SyncOperation.operationId] as stable
  /// tie-breaks — never bare insertion order, which would silently change
  /// if the queue were ever rebuilt from persisted state in a different
  /// order.
  List<SyncOperation<T>> get pendingInOrder {
    final pending =
        _operations
            .where((o) => o.status == SyncOperationStatus.pending)
            .toList()
          ..sort((a, b) {
            final bySequence = a.sequence.compareTo(b.sequence);
            if (bySequence != 0) return bySequence;
            final byQueuedAt = a.queuedAt.compareTo(b.queuedAt);
            if (byQueuedAt != 0) return byQueuedAt;
            return a.operationId.compareTo(b.operationId);
          });
    return pending;
  }

  SyncOperation<T>? operationFor(String operationId) {
    for (final operation in _operations) {
      if (operation.operationId == operationId) return operation;
    }
    return null;
  }

  /// Marks an attempt starting — increments [SyncOperation.attemptCount]
  /// so retry counts are always visible, never silently lost.
  void markSyncing(String operationId) {
    _update(
      operationId,
      (op) => op.copyWith(
        status: SyncOperationStatus.syncing,
        attemptCount: op.attemptCount + 1,
      ),
    );
  }

  /// Terminal, successful state — a confirmed operation is never
  /// reprocessed by [pendingInOrder] again, which is what makes a
  /// duplicate reward structurally impossible from this queue's side (see
  /// module doc comment: "no duplicate reward possibility").
  void markConfirmed(String operationId) {
    _update(
      operationId,
      (op) => op.copyWith(status: SyncOperationStatus.confirmed),
    );
  }

  /// Retry-safe: a failed operation goes back to `pending` (not removed),
  /// so it will be attempted again by [pendingInOrder] — never silently
  /// dropped.
  void markFailed(String operationId) {
    _update(
      operationId,
      (op) => op.copyWith(status: SyncOperationStatus.pending),
    );
  }

  /// Terminal, non-retried state — a conflict needs an explicit decision
  /// (from a future conflict-resolution flow), not an automatic retry.
  void markConflict(String operationId) {
    _update(
      operationId,
      (op) => op.copyWith(status: SyncOperationStatus.conflict),
    );
  }

  void _update(
    String operationId,
    SyncOperation<T> Function(SyncOperation<T> current) transform,
  ) {
    final index = _operations.indexWhere((o) => o.operationId == operationId);
    if (index == -1) return;
    _operations[index] = transform(_operations[index]);
  }
}
