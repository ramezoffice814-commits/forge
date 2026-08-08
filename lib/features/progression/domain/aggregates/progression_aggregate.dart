import 'package:flutter/foundation.dart';

import '../../../missions/domain/enums/mission_category.dart';
import '../entities/achievement_definition.dart';
import '../entities/achievement_evaluation_result.dart';
import '../entities/category_progress.dart';
import '../entities/completed_mission_summary.dart';
import '../entities/level_definition.dart';
import '../entities/mission_history_snapshot.dart';
import '../entities/user_progression_profile.dart';
import '../entities/user_title.dart';
import '../events/progression_event.dart';
import '../policies/level_policy.dart';
import '../policies/title_policy.dart';
import '../services/achievement_evaluator.dart';
import '../services/mission_history_snapshot_builder.dart';

/// The full, deterministically-derived result of one rehydration: the
/// profile itself, plus the achievement/level context the UI needs without
/// re-deriving anything.
///
/// Two things feed this, and both must be held constant for "same input,
/// same output" to hold: [ProgressionAggregate.rehydrate]'s `events` (the
/// XP/level/achievement/title audit trail) and `completions` (the raw
/// mission-completion history levels/titles/achievements are actually
/// computed from). Events record *when* something was first detected —
/// they never invent XP or unlocks that aren't independently justified by
/// the completion history, which is why level/title/achievement status
/// shown in the UI is always freshly computed from `completions` rather
/// than trusted blindly from an event payload (see the class-level doc
/// comment for the full reasoning).
@immutable
class ProgressionAggregate {
  const ProgressionAggregate({
    required this.profile,
    required this.events,
    required this.snapshot,
    required this.achievements,
    required this.currentLevelDefinition,
    required this.nextLevelDefinition,
    required this.levelProgress,
  });

  final UserProgressionProfile profile;
  final List<ProgressionEvent> events;
  final MissionHistorySnapshot snapshot;
  final AchievementEvaluationResult achievements;
  final LevelDefinition currentLevelDefinition;
  final LevelDefinition? nextLevelDefinition;

  /// 0–1 toward [nextLevelDefinition]; `1.0` at the top level.
  final double levelProgress;

  factory ProgressionAggregate.rehydrate({
    required String userId,
    required List<ProgressionEvent> events,
    required List<CompletedMissionSummary> completions,
    required List<LevelDefinition> levelCatalog,
    required List<UserTitleDefinition> titleCatalog,
    required UserTitleDefinition titleFallback,
    required List<AchievementDefinition> achievementCatalog,
    required DateTime now,
  }) {
    final sortedEvents = [...events]
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

    var provisionalXp = 0;
    var confirmedXp = 0; // never set > 0 in this phase — see trust notes.
    final unlockedIds = <String>{};
    DateTime? createdAt;
    var updatedAt = now;

    for (final event in sortedEvents) {
      createdAt ??= event.occurredAt;
      updatedAt = event.occurredAt;
      switch (event) {
        case XpPreviewCalculated(:final evaluation):
          provisionalXp += evaluation.finalXpPreview;
        case AchievementUnlocked(:final achievementId):
          unlockedIds.add(achievementId);
        case LevelReached():
        case TitleUnlocked():
          break; // audit-trail only — level/title are derived fresh below.
      }
    }

    final snapshot = MissionHistorySnapshotBuilder.build(
      completions,
      asOf: now,
    );

    final achievementResult = AchievementEvaluator.evaluate(
      snapshot: snapshot,
      unlockedIds: unlockedIds,
      catalog: achievementCatalog,
      unlockTimestampForNew: now,
    );

    final title = TitlePolicy.evaluate(
      snapshot: snapshot,
      catalog: titleCatalog,
      fallback: titleFallback,
      reasonFor: (def) => def.description,
    );

    final totalXp = confirmedXp + provisionalXp;
    final currentLevelDef = LevelPolicy.levelFor(totalXp, levelCatalog);
    final nextLevelDef = LevelPolicy.nextLevel(currentLevelDef, levelCatalog);
    final levelProgress = LevelPolicy.progressToNextLevel(
      totalXp,
      levelCatalog,
    );

    final categoryProgress = <MissionCategory, CategoryProgress>{
      for (final category in snapshot.categoriesTried)
        category: CategoryProgress.fromCompletedCount(
          category,
          snapshot.completionsByCategory[category] ?? 0,
          totalXpPreview: 0,
        ),
    };

    // Newly-unlocked achievements are folded into the *displayed* unlocked
    // set immediately (real-time UX) even before a caller has appended the
    // corresponding `AchievementUnlocked` event — see the class doc comment.
    final displayedUnlockedIds = {
      ...unlockedIds,
      for (final a in achievementResult.newlyUnlocked) a.definition.id,
    };

    final profile = UserProgressionProfile(
      userId: userId,
      currentLevel: currentLevelDef.levelNumber,
      totalConfirmedXp: confirmedXp,
      provisionalXp: provisionalXp,
      currentTitle: title,
      unlockedAchievementIds: displayedUnlockedIds,
      categoryProgress: categoryProgress,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt,
    );

    return ProgressionAggregate(
      profile: profile,
      events: sortedEvents,
      snapshot: snapshot,
      achievements: achievementResult,
      currentLevelDefinition: currentLevelDef,
      nextLevelDefinition: nextLevelDef,
      levelProgress: levelProgress,
    );
  }
}
