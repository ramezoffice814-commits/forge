import 'package:flutter/foundation.dart';

import '../../../missions/domain/enums/mission_category.dart';

/// A deterministic rollup of a user's completion history — the one shared
/// input every progression policy (`XpCalculationPolicy`, `TitlePolicy`,
/// `AchievementEvaluator`) reads instead of each re-deriving its own stats
/// from a raw completion list. The same list of completions always builds
/// the same snapshot (see `MissionHistorySnapshotBuilder`).
@immutable
class MissionHistorySnapshot {
  const MissionHistorySnapshot({
    required this.totalCompletions,
    required this.completionsByCategory,
    required this.completionsByDefinitionId,
    required this.categoriesTried,
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.daysSinceLastCompletion,
    required this.advancedOrChallengingCompletions,
    required this.recoveryCompletions,
    required this.justReturnedFromInactivity,
  });

  const MissionHistorySnapshot.empty()
    : totalCompletions = 0,
      completionsByCategory = const {},
      completionsByDefinitionId = const {},
      categoriesTried = const {},
      currentStreakDays = 0,
      longestStreakDays = 0,
      daysSinceLastCompletion = -1,
      advancedOrChallengingCompletions = 0,
      recoveryCompletions = 0,
      justReturnedFromInactivity = false;

  final int totalCompletions;
  final Map<MissionCategory, int> completionsByCategory;

  /// Keyed by `MissionDefinition.id` — how many times this exact mission has
  /// been completed recently, the input `XpCalculationPolicy` uses for
  /// diminishing returns on repeated trivial missions.
  final Map<String, int> completionsByDefinitionId;

  final Set<MissionCategory> categoriesTried;
  final int currentStreakDays;
  final int longestStreakDays;

  /// `-1` when there is no prior completion at all (a brand-new user).
  final int daysSinceLastCompletion;

  final int advancedOrChallengingCompletions;
  final int recoveryCompletions;

  /// True when the most recent completion followed a gap of 3+ days —
  /// feeds the "returned after inactivity" achievement, phrased as a
  /// neutral fact rather than a judgement about *why* the gap happened.
  final bool justReturnedFromInactivity;
}
