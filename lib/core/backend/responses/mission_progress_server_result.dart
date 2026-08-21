import 'package:flutter/foundation.dart';

import 'server_validation_status.dart';

@immutable
class MissionProgressServerResult {
  const MissionProgressServerResult({
    required this.status,
    required this.missionInstanceId,
    required this.acceptedSequence,
    required this.serverTimestamp,
    required this.confirmationId,
    this.reasons = const [],
  });

  final ServerValidationStatus status;
  final String missionInstanceId;

  /// The highest sequence number the server has now accepted for this
  /// mission — the client's own local sequence should never exceed this
  /// by more than one in-flight command.
  final int acceptedSequence;

  final DateTime serverTimestamp;
  final String confirmationId;
  final List<String> reasons;
}
