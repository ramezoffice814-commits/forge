import 'package:flutter/foundation.dart';

import '../../../missions/domain/enums/mission_category.dart';
import 'category_progress.dart';
import 'user_title.dart';

/// The user's whole progression state, derived by folding
/// `ProgressionEvent`s through `ProgressionAggregate` — never mutated
/// directly, never partially updated in place.
///
/// Trust boundary: [totalConfirmedXp] is the only number a future backend
/// would ever treat as real; [provisionalXp] and [currentLevel] (which
/// includes provisional XP, so the UI can show live progress) are always
/// local-preview-only. Nothing in this module ever promotes provisional XP
/// to confirmed on its own — that requires a server round trip this phase
/// deliberately doesn't implement (see the module's trust-boundary notes).
@immutable
class UserProgressionProfile {
  const UserProgressionProfile({
    required this.userId,
    required this.currentLevel,
    required this.totalConfirmedXp,
    required this.provisionalXp,
    required this.currentTitle,
    required this.unlockedAchievementIds,
    required this.categoryProgress,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProgressionProfile.initial({
    required String userId,
    required UserTitle startingTitle,
    required DateTime now,
  }) {
    return UserProgressionProfile(
      userId: userId,
      currentLevel: 1,
      totalConfirmedXp: 0,
      provisionalXp: 0,
      currentTitle: startingTitle,
      unlockedAchievementIds: const {},
      categoryProgress: const {},
      createdAt: now,
      updatedAt: now,
    );
  }

  final String userId;

  /// Preview-inclusive: `LevelPolicy.levelFor(totalConfirmedXp +
  /// provisionalXp)`. Shown freely in the UI, but never reported as a
  /// confirmed rank to anything competitive.
  final int currentLevel;

  final int totalConfirmedXp;
  final int provisionalXp;

  final UserTitle currentTitle;
  final Set<String> unlockedAchievementIds;
  final Map<MissionCategory, CategoryProgress> categoryProgress;

  final DateTime createdAt;
  final DateTime updatedAt;

  int get previewTotalXp => totalConfirmedXp + provisionalXp;

  UserProgressionProfile copyWith({
    int? currentLevel,
    int? totalConfirmedXp,
    int? provisionalXp,
    UserTitle? currentTitle,
    Set<String>? unlockedAchievementIds,
    Map<MissionCategory, CategoryProgress>? categoryProgress,
    DateTime? updatedAt,
  }) {
    return UserProgressionProfile(
      userId: userId,
      currentLevel: currentLevel ?? this.currentLevel,
      totalConfirmedXp: totalConfirmedXp ?? this.totalConfirmedXp,
      provisionalXp: provisionalXp ?? this.provisionalXp,
      currentTitle: currentTitle ?? this.currentTitle,
      unlockedAchievementIds:
          unlockedAchievementIds ?? this.unlockedAchievementIds,
      categoryProgress: categoryProgress ?? this.categoryProgress,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
