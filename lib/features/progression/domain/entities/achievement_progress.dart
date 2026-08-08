import 'package:flutter/foundation.dart';

import 'achievement_definition.dart';

enum AchievementStatus { locked, progressing, unlocked }

/// One achievement's current state for this user — always derived fresh
/// from a [MissionHistorySnapshot] plus the profile's unlocked-id set,
/// never stored as its own mutable flag (see `AchievementEvaluator`).
@immutable
class AchievementProgress {
  const AchievementProgress({
    required this.definition,
    required this.status,
    required this.current,
    required this.target,
    this.unlockedAt,
  });

  final AchievementDefinition definition;
  final AchievementStatus status;
  final int current;
  final int target;
  final DateTime? unlockedAt;

  double get fraction => target <= 0 ? 0 : (current / target).clamp(0, 1);
}
