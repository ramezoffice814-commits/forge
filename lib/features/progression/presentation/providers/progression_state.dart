import 'package:flutter/foundation.dart';

import '../../domain/aggregates/progression_aggregate.dart';
import '../../domain/entities/achievement_progress.dart';
import '../../domain/entities/xp_reward_evaluation.dart';
import '../../domain/usecases/calculate_level_usecase.dart';

@immutable
sealed class ProgressionState {
  const ProgressionState();
}

class ProgressionLoading extends ProgressionState {
  const ProgressionLoading();
}

class ProgressionError extends ProgressionState {
  const ProgressionError(this.message);

  final String message;
}

class ProgressionReady extends ProgressionState {
  const ProgressionReady({
    required this.aggregate,
    this.lastXpEvaluation,
    this.lastLevelResult,
    this.recentlyUnlocked = const [],
  });

  final ProgressionAggregate aggregate;

  /// The most recent mission's XP breakdown — cleared by
  /// `ProgressionController.dismissCelebration`, not automatically, so a
  /// celebration banner never disappears before the user has seen it.
  final XpRewardEvaluation? lastXpEvaluation;
  final LevelCalculationResult? lastLevelResult;
  final List<AchievementProgress> recentlyUnlocked;

  bool get hasCelebration =>
      (lastLevelResult?.justLeveledUp ?? false) || recentlyUnlocked.isNotEmpty;
}
