import 'package:flutter/foundation.dart';

import 'server_validation_status.dart';

@immutable
class MissionAcceptedServerResult {
  const MissionAcceptedServerResult({
    required this.status,
    required this.missionInstanceId,
    required this.serverTimestamp,
    required this.confirmationId,
    this.reasons = const [],
  });

  final ServerValidationStatus status;
  final String missionInstanceId;
  final DateTime serverTimestamp;
  final String confirmationId;
  final List<String> reasons;
}
