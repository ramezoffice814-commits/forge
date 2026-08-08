import 'package:flutter/foundation.dart';

import '../../../missions/domain/enums/mission_category.dart';
import '../../../missions/domain/enums/mission_difficulty_level.dart';

/// The one narrow bridge between the missions module and progression —
/// progression never reads a `MissionAggregate`/`MissionEvent` directly, it
/// only ever sees this already-validated fact: "this mission genuinely
/// reached `completed`". Building one of these is only legitimate for a
/// mission whose lifecycle is actually `completed` (see
/// `MissionCompletionSignalAdapter` in the presentation layer, the one place
/// that's allowed to construct it from a real `MissionAggregate`).
@immutable
class CompletedMissionSummary {
  const CompletedMissionSummary({
    required this.missionInstanceId,
    required this.definitionId,
    required this.userId,
    required this.category,
    required this.difficulty,
    required this.baseXpHint,
    required this.resolvedDurationMinutes,
    required this.recoveryMission,
    required this.completedAt,
  });

  final String missionInstanceId;
  final String definitionId;
  final String userId;
  final MissionCategory category;
  final MissionDifficultyLevel difficulty;

  /// Display-only hint carried over from the mission engine — never
  /// authoritative (see `MissionInstance.xpHint`'s own doc comment). The XP
  /// policy uses it only as the *base* it then adjusts.
  final int baseXpHint;

  final int resolvedDurationMinutes;
  final bool recoveryMission;
  final DateTime completedAt;
}
