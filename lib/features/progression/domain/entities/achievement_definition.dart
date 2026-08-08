import 'package:flutter/foundation.dart';

import '../../../missions/domain/enums/mission_category.dart';
import '../../../missions/domain/enums/mission_difficulty_level.dart';
import 'mission_history_snapshot.dart';

enum AchievementCategory { consistency, exploration, skill, recovery, mastery }

enum AchievementRarity { common, uncommon, rare, epic }

/// What it takes to unlock an achievement, and how to measure progress
/// toward it — every subtype reads only [MissionHistorySnapshot], so
/// criteria stay deterministic and replayable, never randomly evaluated.
@immutable
sealed class AchievementCriteria {
  const AchievementCriteria();

  /// Returns (current, target) — e.g. (3, 10) for "3 of 10 coding
  /// missions". `current` is clamped to `target` by the caller, never here.
  (int current, int target) progress(MissionHistorySnapshot snapshot);
}

/// "Complete N missions total."
final class TotalCompletionsCriteria extends AchievementCriteria {
  const TotalCompletionsCriteria(this.target);

  final int target;

  @override
  (int, int) progress(MissionHistorySnapshot snapshot) =>
      (snapshot.totalCompletions, target);
}

/// "Complete N missions in [category]."
final class CategoryCompletionsCriteria extends AchievementCriteria {
  const CategoryCompletionsCriteria({
    required this.category,
    required this.target,
  });

  final MissionCategory category;
  final int target;

  @override
  (int, int) progress(MissionHistorySnapshot snapshot) =>
      (snapshot.completionsByCategory[category] ?? 0, target);
}

/// "Try N different categories."
final class CategoryVarietyCriteria extends AchievementCriteria {
  const CategoryVarietyCriteria(this.target);

  final int target;

  @override
  (int, int) progress(MissionHistorySnapshot snapshot) =>
      (snapshot.categoriesTried.length, target);
}

/// "Maintain an N-day streak."
final class StreakCriteria extends AchievementCriteria {
  const StreakCriteria(this.targetDays);

  final int targetDays;

  @override
  (int, int) progress(MissionHistorySnapshot snapshot) =>
      (snapshot.currentStreakDays, targetDays);
}

/// "Complete N missions at [minimumDifficulty] or above."
final class DifficultyCompletionsCriteria extends AchievementCriteria {
  const DifficultyCompletionsCriteria({
    required this.minimumDifficulty,
    required this.target,
  });

  final MissionDifficultyLevel minimumDifficulty;
  final int target;

  @override
  (int, int) progress(MissionHistorySnapshot snapshot) =>
      (snapshot.advancedOrChallengingCompletions, target);
}

/// "Complete N recovery missions."
final class RecoveryCompletionsCriteria extends AchievementCriteria {
  const RecoveryCompletionsCriteria(this.target);

  final int target;

  @override
  (int, int) progress(MissionHistorySnapshot snapshot) =>
      (snapshot.recoveryCompletions, target);
}

/// Binary: did the most recent completion follow a 3+ day gap? Framed
/// neutrally — a fact about return, never a comment on the absence.
final class ReturnedFromInactivityCriteria extends AchievementCriteria {
  const ReturnedFromInactivityCriteria();

  @override
  (int, int) progress(MissionHistorySnapshot snapshot) =>
      (snapshot.justReturnedFromInactivity ? 1 : 0, 1);
}

@immutable
class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.criteria,
    required this.rarity,
    required this.iconId,
    this.hiddenUntilUnlocked = false,
    this.active = true,
  });

  final String id;
  final String name;
  final String description;
  final AchievementCategory category;
  final AchievementCriteria criteria;
  final AchievementRarity rarity;
  final String iconId;

  /// Name/description are withheld in the UI until unlocked — see
  /// `AchievementCard`'s locked-and-hidden rendering.
  final bool hiddenUntilUnlocked;

  final bool active;
}
