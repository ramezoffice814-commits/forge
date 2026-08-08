import 'package:flutter/foundation.dart';

import 'achievement_progress.dart';

@immutable
class AchievementEvaluationResult {
  const AchievementEvaluationResult({
    required this.newlyUnlocked,
    required this.alreadyUnlocked,
    required this.progressUpdates,
    required this.reasons,
  });

  /// Achievements that crossed from not-unlocked to unlocked in *this*
  /// evaluation — the only ones a caller should celebrate/announce.
  final List<AchievementProgress> newlyUnlocked;

  /// Already-unlocked achievements, re-affirmed (never re-triggered).
  final List<AchievementProgress> alreadyUnlocked;

  /// Every visible, not-yet-unlocked achievement with its current progress
  /// (hidden-until-unlocked ones are excluded until they unlock).
  final List<AchievementProgress> progressUpdates;

  final List<String> reasons;
}
