import 'package:flutter/foundation.dart';

import 'mission_sync_status.dart';

/// The offline-queue envelope for one locally-appended event — foundation
/// only. No real networking exists yet; this just tracks *what would need
/// to sync and its retry state* so a future sync worker has somewhere to
/// start from. Confirmed/permanently-failed entries are kept, never
/// deleted, so the queue itself stays auditable.
@immutable
class PendingMissionEvent {
  const PendingMissionEvent({
    required this.localEventId,
    required this.missionInstanceId,
    required this.idempotencyKey,
    required this.sequenceNumber,
    required this.queuedAt,
    this.payloadVersion = 1,
    this.attemptCount = 0,
    this.lastAttemptAt,
    this.syncStatus = MissionSyncStatus.pending,
    this.lastErrorCode,
  });

  final String localEventId;
  final String missionInstanceId;
  final String idempotencyKey;
  final int sequenceNumber;
  final int payloadVersion;
  final DateTime queuedAt;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final MissionSyncStatus syncStatus;
  final String? lastErrorCode;

  /// Exponential backoff metadata only (base 2s, capped at 5 minutes) —
  /// there is no retry loop actually consuming this yet (spec: "no busy
  /// retry loop", "no actual network sync yet").
  Duration get nextRetryBackoff {
    final exponent = attemptCount.clamp(0, 8);
    final seconds = 2 * (1 << exponent);
    return Duration(seconds: seconds.clamp(2, 300));
  }

  bool get isTerminal =>
      syncStatus == MissionSyncStatus.confirmed ||
      syncStatus == MissionSyncStatus.permanentFailure;

  PendingMissionEvent copyWith({
    int? attemptCount,
    DateTime? lastAttemptAt,
    MissionSyncStatus? syncStatus,
    Object? lastErrorCode = _unset,
  }) {
    return PendingMissionEvent(
      localEventId: localEventId,
      missionInstanceId: missionInstanceId,
      idempotencyKey: idempotencyKey,
      sequenceNumber: sequenceNumber,
      payloadVersion: payloadVersion,
      queuedAt: queuedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      syncStatus: syncStatus ?? this.syncStatus,
      lastErrorCode: identical(lastErrorCode, _unset)
          ? this.lastErrorCode
          : lastErrorCode as String?,
    );
  }
}

const _unset = Object();
