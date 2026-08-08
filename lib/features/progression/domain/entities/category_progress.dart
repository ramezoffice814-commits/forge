import 'package:flutter/foundation.dart';

import '../../../missions/domain/enums/mission_category.dart';

/// Cosmetic, motivational "mastery" framing for one category — never a
/// certification or expertise claim (see spec section 12).
enum CategoryMasteryTier { beginner, practitioner, advanced, master }

String categoryMasteryTierLabel(CategoryMasteryTier tier) {
  return switch (tier) {
    CategoryMasteryTier.beginner => 'Beginner',
    CategoryMasteryTier.practitioner => 'Practitioner',
    CategoryMasteryTier.advanced => 'Advanced',
    CategoryMasteryTier.master => 'Master',
  };
}

/// Deterministic completion-count thresholds for each tier — a flat lookup
/// table rather than an if/else chain, so adding a tier later is a one-line
/// change here, not a rewrite of the policy that reads it.
abstract final class CategoryMasteryThresholds {
  static const Map<CategoryMasteryTier, int> minimumCompletions = {
    CategoryMasteryTier.beginner: 0,
    CategoryMasteryTier.practitioner: 5,
    CategoryMasteryTier.advanced: 15,
    CategoryMasteryTier.master: 30,
  };

  static CategoryMasteryTier tierFor(int completedCount) {
    // `CategoryMasteryTier.values` is declared in ascending-threshold order,
    // so the last tier whose minimum is met is the highest one reached.
    var tier = CategoryMasteryTier.beginner;
    for (final candidate in CategoryMasteryTier.values) {
      if (completedCount >= minimumCompletions[candidate]!) {
        tier = candidate;
      }
    }
    return tier;
  }

  /// `null` once [CategoryMasteryTier.master] (the top tier) is reached.
  static int? nextTierRequirement(int completedCount) {
    final remaining =
        minimumCompletions.values
            .where((threshold) => threshold > completedCount)
            .toList()
          ..sort();
    return remaining.isEmpty ? null : remaining.first;
  }
}

@immutable
class CategoryProgress {
  const CategoryProgress({
    required this.category,
    required this.completedCount,
    required this.totalXpPreview,
    required this.currentTier,
    required this.nextTierRequirement,
  });

  factory CategoryProgress.fromCompletedCount(
    MissionCategory category,
    int completedCount, {
    required int totalXpPreview,
  }) {
    return CategoryProgress(
      category: category,
      completedCount: completedCount,
      totalXpPreview: totalXpPreview,
      currentTier: CategoryMasteryThresholds.tierFor(completedCount),
      nextTierRequirement: CategoryMasteryThresholds.nextTierRequirement(
        completedCount,
      ),
    );
  }

  final MissionCategory category;
  final int completedCount;
  final int totalXpPreview;
  final CategoryMasteryTier currentTier;

  /// Completions still needed to reach the next tier — `null` at the top
  /// tier already.
  final int? nextTierRequirement;
}
