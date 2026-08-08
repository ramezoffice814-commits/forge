import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/progression/data/catalog/achievement_catalog.dart';
import 'package:forge/features/progression/data/catalog/level_catalog.dart';
import 'package:forge/features/progression/data/catalog/title_catalog.dart';
import 'package:forge/features/progression/domain/aggregates/progression_aggregate.dart';
import 'package:forge/features/progression/domain/entities/xp_reward_evaluation.dart';
import 'package:forge/features/progression/domain/events/progression_event.dart';

import '../../../support/progression_test_helpers.dart';

void main() {
  final levels = LevelCatalog.build();
  final titles = TitleCatalog.build();
  final achievements = AchievementCatalog.build();
  final now = DateTime.utc(2026, 8, 10);

  XpPreviewCalculated xpEvent(String id, int seq, int xp) {
    return XpPreviewCalculated(
      eventId: id,
      userId: testProgressionUserId,
      occurredAt: now,
      sequenceNumber: seq,
      evaluation: XpRewardEvaluation(
        missionInstanceId: id,
        baseXp: xp,
        difficultyMultiplier: 1,
        categoryMultiplier: 1,
        consistencyBonus: 0,
        recoveryBonus: 0,
        penaltyAdjustments: 0,
        finalXpPreview: xp,
        reasons: const [],
        evaluationVersion: '1.0.0',
      ),
    );
  }

  ProgressionAggregate rehydrate(List events, List completions) {
    return ProgressionAggregate.rehydrate(
      userId: testProgressionUserId,
      events: events.cast(),
      completions: completions.cast(),
      levelCatalog: levels,
      titleCatalog: titles,
      titleFallback: TitleCatalog.starter,
      achievementCatalog: achievements,
      now: now,
    );
  }

  test('an empty aggregate starts at level 1 with zero XP', () {
    final aggregate = rehydrate([], []);
    expect(aggregate.profile.currentLevel, 1);
    expect(aggregate.profile.previewTotalXp, 0);
    expect(aggregate.profile.totalConfirmedXp, 0);
  });

  test('provisionalXp accumulates from XpPreviewCalculated events, never '
      'from totalConfirmedXp', () {
    final aggregate = rehydrate([
      xpEvent('e1', 1, 20),
      xpEvent('e2', 2, 30),
    ], []);
    expect(aggregate.profile.provisionalXp, 50);
    expect(aggregate.profile.totalConfirmedXp, 0);
    expect(aggregate.profile.previewTotalXp, 50);
  });

  test('replaying the same events and completions always produces the '
      'same profile (determinism)', () {
    final events = [xpEvent('e1', 1, 40)];
    final completions = [testCompletedSummary(completedAt: now)];

    final a = rehydrate(events, completions);
    final b = rehydrate(events, completions);

    expect(a.profile.currentLevel, b.profile.currentLevel);
    expect(a.profile.provisionalXp, b.profile.provisionalXp);
    expect(a.profile.currentTitle.id, b.profile.currentTitle.id);
    expect(a.profile.unlockedAchievementIds, b.profile.unlockedAchievementIds);
  });

  test('replaying events out of list order folds in sequenceNumber order', () {
    final ordered = rehydrate([xpEvent('e1', 1, 10), xpEvent('e2', 2, 5)], []);
    final shuffled = rehydrate([xpEvent('e2', 2, 5), xpEvent('e1', 1, 10)], []);
    expect(shuffled.profile.provisionalXp, ordered.profile.provisionalXp);
  });

  test('AchievementUnlocked events prevent a re-detected achievement from '
      'appearing as newly unlocked again', () {
    final completions = [testCompletedSummary(completedAt: now)];
    final aggregate = rehydrate([
      AchievementUnlocked(
        eventId: 'a1',
        userId: testProgressionUserId,
        occurredAt: now,
        sequenceNumber: 1,
        achievementId: 'first_mission',
      ),
    ], completions);

    expect(
      aggregate.achievements.newlyUnlocked
          .map((a) => a.definition.id)
          .contains('first_mission'),
      isFalse,
    );
    expect(
      aggregate.achievements.alreadyUnlocked
          .map((a) => a.definition.id)
          .contains('first_mission'),
      isTrue,
    );
  });

  test('a newly-qualifying achievement with no event yet still shows as '
      'unlocked immediately (real-time UX)', () {
    final completions = [testCompletedSummary(completedAt: now)];
    final aggregate = rehydrate([], completions);
    expect(aggregate.profile.unlockedAchievementIds, contains('first_mission'));
  });
}
