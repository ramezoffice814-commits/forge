import 'package:flutter/foundation.dart';

import '../enums/data_confidence.dart';
import '../enums/mission_category.dart';
import '../enums/mission_difficulty_level.dart';
import 'mission_result.dart';

/// Aggregated, category-scoped performance — deliberately not "how many
/// missions in category X" alone, since that number means nothing to a
/// policy without success/miss context.
@immutable
class CategoryPerformance {
  const CategoryPerformance({
    required this.category,
    this.completed = 0,
    this.missed = 0,
    this.averageEffort,
    this.lastDifficulty,
    this.consecutiveComparableSuccesses = 0,
    this.consecutiveComparableMisses = 0,
  });

  final MissionCategory category;
  final int completed;
  final int missed;

  /// 1–5 average, null if never self-reported.
  final double? averageEffort;
  final MissionDifficultyLevel? lastDifficulty;

  /// "Comparable" = same category, same difficulty tier as the current
  /// assignment — what `AdaptiveDifficultyPolicy` actually needs, since a
  /// streak of easy wins shouldn't justify jumping to advanced.
  final int consecutiveComparableSuccesses;
  final int consecutiveComparableMisses;

  int get totalAttempts => completed + missed;
  double get successRate => totalAttempts == 0 ? 0 : completed / totalAttempts;
}

/// Recent performance summary the engine reasons from — never the full
/// mission log verbatim (see the privacy notes in `MissionSafetyPolicy`).
@immutable
class BehavioralHistory {
  const BehavioralHistory({
    this.recentMissionResults = const [],
    this.completionRate7Days = 0,
    this.completionRate30Days = 0,
    this.consecutiveSuccesses = 0,
    this.consecutiveMisses = 0,
    this.averageCompletionMinutes,
    this.selfReportedEffortAverage,
    this.categoryPerformance = const {},
    this.recentMissionIds = const [],
    this.lastCompletedAt,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.recoveryMissionSuccesses = 0,
    this.recentDifficultyChangeCount = 0,
    this.preferredCompletionHours = const [],
    this.dataConfidence = DataConfidence.low,
  });

  final List<MissionResult> recentMissionResults;
  final double completionRate7Days;
  final double completionRate30Days;
  final int consecutiveSuccesses;
  final int consecutiveMisses;
  final double? averageCompletionMinutes;
  final double? selfReportedEffortAverage;
  final Map<MissionCategory, CategoryPerformance> categoryPerformance;

  /// Most-recent-first; used for repeat-cooldown checks.
  final List<String> recentMissionIds;
  final DateTime? lastCompletedAt;
  final int currentStreak;
  final int longestStreak;
  final int recoveryMissionSuccesses;
  final int recentDifficultyChangeCount;
  final List<int> preferredCompletionHours;
  final DataConfidence dataConfidence;

  CategoryPerformance performanceFor(MissionCategory category) {
    return categoryPerformance[category] ??
        CategoryPerformance(category: category);
  }
}
