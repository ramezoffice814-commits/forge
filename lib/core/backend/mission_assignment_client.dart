import 'package:flutter/foundation.dart';

/// The one seam live-mode mission assignment goes through — mock mode
/// never touches this at all (spec section 5/8: "preserve mock mode",
/// "MOCK mode: keep the existing deterministic local mission engine").
/// Wraps `assign-daily-mission` (supabase/functions/assign-daily-
/// mission/index.ts), which itself is a thin wrapper around
/// `forge_assign_daily_mission` (supabase/migrations/
/// 20260820090000_mission_assignment.sql) — see that SQL function's own
/// doc comment for the full server/client selection-authority decision.
abstract class MissionAssignmentClient {
  Future<MissionAssignmentResult> assignDailyMission({
    required String commandId,
    required String idempotencyKey,
    String? requestedMissionDefinitionId,
    String? requestedCategory,
  });
}

@immutable
class MissionAssignmentResult {
  const MissionAssignmentResult({
    required this.missionInstanceId,
    required this.missionDefinitionId,
    required this.assignedDate,
    required this.serverTimestamp,
    required this.confirmationId,
    this.reasons = const [],
  });

  final String missionInstanceId;
  final String missionDefinitionId;
  final DateTime assignedDate;
  final DateTime serverTimestamp;
  final String confirmationId;
  final List<String> reasons;
}
