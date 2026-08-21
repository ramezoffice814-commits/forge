import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/sync/domain/enums/sync_operation_status.dart';
import 'sync_queueing_backend_client.dart';

/// Coarse status a UI can show for the whole queue — never per-command
/// detail (that lives in the queue itself). [conflict] means at least one
/// queued command failed in a way [flushPending] won't silently retry
/// forever (spec section 6: "user-visible conflict state when automatic
/// reconciliation is unsafe").
enum SyncExecutorStatus { idle, syncing, pendingRetry, conflict }

@immutable
class SyncExecutorSnapshot {
  const SyncExecutorSnapshot({
    required this.status,
    required this.pendingCount,
    required this.conflictCount,
  });

  final SyncExecutorStatus status;
  final int pendingCount;
  final int conflictCount;
}

/// A lightweight executor over [SyncQueueingBackendClient] — not a
/// background daemon (spec section 7: "do not build a heavy daemon"),
/// just one method ([runOnce]) a caller invokes at well-defined moments
/// (app startup, reconnect, a manual "retry sync" action, a bounded
/// periodic timer the *caller* owns). This class never schedules its own
/// timers — that would be the daemon the spec explicitly says not to
/// build.
///
/// Ordering/dependency-blocking and "never mark failed confirmed" are
/// already guaranteed by [SyncQueueingBackendClient.flushPending] itself
/// (see that class's own doc comment) — this executor adds only status
/// reporting and a backoff *delay calculator* callers can use between
/// retries; it does not sleep internally.
class SyncQueueExecutor {
  SyncQueueExecutor(
    this._client, {
    this.baseBackoff = const Duration(seconds: 2),
    this.maxBackoff = const Duration(seconds: 30),
  });

  final SyncQueueingBackendClient _client;
  final Duration baseBackoff;
  final Duration maxBackoff;

  SyncExecutorStatus _status = SyncExecutorStatus.idle;

  SyncExecutorSnapshot get snapshot {
    final pending = _client.queue.pendingInOrder;
    final conflicted = _client.queue.all
        .where((op) => op.status == SyncOperationStatus.conflict)
        .length;
    return SyncExecutorSnapshot(
      status: _status,
      pendingCount: pending.length,
      conflictCount: conflicted,
    );
  }

  /// Attempts every currently-pending command once, in order, then
  /// updates [snapshot] to reflect the result — empty queue afterward
  /// means [SyncExecutorStatus.idle]; a still-nonempty queue with no
  /// conflicted rows means [SyncExecutorStatus.pendingRetry] (worth
  /// trying again later, e.g. still offline); any conflicted row means
  /// [SyncExecutorStatus.conflict] (do not auto-retry — needs a user
  /// decision or an explicit "resolved" action first).
  Future<SyncExecutorSnapshot> runOnce() async {
    _status = SyncExecutorStatus.syncing;
    await _client.flushPending();

    final hasConflict = _client.queue.all.any(
      (op) => op.status == SyncOperationStatus.conflict,
    );
    final stillPending = _client.queue.pendingInOrder.isNotEmpty;

    _status = hasConflict
        ? SyncExecutorStatus.conflict
        : stillPending
        ? SyncExecutorStatus.pendingRetry
        : SyncExecutorStatus.idle;

    return snapshot;
  }

  /// Exponential-ish backoff, capped at [maxBackoff] — a pure
  /// calculation; whether/when to actually wait this long is entirely
  /// the caller's decision (spec: "do not build a heavy daemon").
  Duration backoffFor(int attemptCount) {
    final safeAttempt = attemptCount.clamp(0, 8);
    final scaled = baseBackoff * (1 << safeAttempt);
    return scaled > maxBackoff ? maxBackoff : scaled;
  }
}
