import 'package:flutter/foundation.dart';

import 'sync_conflict.dart';

@immutable
class SyncResult {
  const SyncResult.success(this.operationId)
    : failureReason = null,
      conflict = null;

  const SyncResult.failure(this.operationId, this.failureReason)
    : conflict = null;

  const SyncResult.conflict(this.operationId, this.conflict)
    : failureReason = null;

  final String operationId;
  final String? failureReason;
  final SyncConflict? conflict;

  bool get isSuccess => failureReason == null && conflict == null;
}
