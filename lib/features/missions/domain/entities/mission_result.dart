import 'package:flutter/foundation.dart';

import '../enums/mission_category.dart';
import '../enums/mission_difficulty_level.dart';
import '../enums/mission_result_status.dart';
import '../enums/rejection_reason.dart';

/// A single past mission outcome — the minimum a policy needs to reason
/// about "did this work for the user," never a full behavioral log.
@immutable
class MissionResult {
  const MissionResult({
    required this.missionId,
    required this.category,
    required this.assignedDifficulty,
    required this.assignedAt,
    required this.status,
    this.acceptedAt,
    this.completedAt,
    this.actualMinutes,
    this.selfReportedEffort,
    this.skippedReason,
    this.usedAccessibilityAlternative = false,
    this.proofSubmitted = false,
    this.source = 'engine',
  });

  final String missionId;
  final MissionCategory category;
  final MissionDifficultyLevel assignedDifficulty;
  final DateTime assignedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final MissionResultStatus status;
  final int? actualMinutes;

  /// 1 (very easy) – 5 (very hard), user self-reported.
  final int? selfReportedEffort;
  final RejectionReason? skippedReason;
  final bool usedAccessibilityAlternative;
  final bool proofSubmitted;
  final String source;

  bool get isSuccess => status == MissionResultStatus.completed;
  bool get isMiss =>
      status == MissionResultStatus.skipped ||
      status == MissionResultStatus.expired;
}
