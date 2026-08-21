import 'package:flutter/foundation.dart';

@immutable
class SyncConflict {
  const SyncConflict({
    required this.operationId,
    required this.reason,
    required this.detectedAt,
  });

  final String operationId;
  final String reason;
  final DateTime detectedAt;
}
