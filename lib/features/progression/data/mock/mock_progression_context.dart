import '../../../missions/domain/enums/mission_category.dart';
import '../../../missions/domain/enums/mission_difficulty_level.dart';
import '../../domain/entities/completed_mission_summary.dart';
import '../../domain/repositories/progression_repository.dart';
import '../../domain/usecases/calculate_level_usecase.dart';
import '../../domain/usecases/evaluate_achievements_usecase.dart';
import '../../domain/usecases/evaluate_mission_reward_usecase.dart';
import '../../domain/usecases/get_titles_usecase.dart';

/// Seeds a plausible "you've been at this a couple of weeks" starting
/// history — otherwise the Progression page would be empty on first launch,
/// exactly like `MockMissionContexts` seeding `BehavioralHistory` for the
/// mission engine. Every seeded completion is replayed through the real use
/// cases (never inserted as a shortcut profile object), so the resulting
/// state is exactly what a real user's history would have produced.
///
/// Seed dates are anchored to [now] (real wall-clock time by default) —
/// *not* a fixed calendar date — so "a 4-day streak ending yesterday" is
/// still true relative to whatever day the app actually runs on, and stays
/// consistent with real mission completions timestamped by
/// `SystemMissionClock`. Tests that want fully reproducible output should
/// pass a fixed [now] explicitly (see [exampleReferenceInstant]).
abstract final class MockProgressionContext {
  /// A convenient fixed instant for tests that want reproducible output —
  /// not used by [seed] unless a caller explicitly passes it as [now].
  static final DateTime exampleReferenceInstant = DateTime.utc(2026, 8, 5, 9);

  static const seedUserId = 'demo-user';

  static Future<void> seed(
    ProgressionRepository repository, {
    String userId = seedUserId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final evaluateReward = EvaluateMissionRewardUseCase(repository);
    final calculateLevel = CalculateLevelUseCase(repository);
    final evaluateAchievements = EvaluateAchievementsUseCase(repository);
    final getTitles = GetTitlesUseCase(repository);

    for (final summary in _seedCompletions(userId, effectiveNow)) {
      await evaluateReward(summary);
      await calculateLevel(userId, now: summary.completedAt);
      await evaluateAchievements(userId, now: summary.completedAt);
      await getTitles(userId, now: summary.completedAt);
    }
  }

  static List<CompletedMissionSummary> _seedCompletions(
    String userId,
    DateTime now,
  ) {
    const categories = [
      MissionCategory.fitness,
      MissionCategory.coding,
      MissionCategory.reading,
      MissionCategory.mindfulness,
    ];

    final completions = <CompletedMissionSummary>[];

    // A handful of sparse completions further back...
    const sparseDaysAgo = [13, 11, 9, 8, 6];
    for (final daysAgo in sparseDaysAgo) {
      completions.add(
        _summary(
          userId,
          categories[daysAgo % categories.length],
          now: now,
          daysAgo: daysAgo,
          index: daysAgo,
        ),
      );
    }

    // ...building into a solid 4-day streak ending yesterday.
    for (var daysAgo = 4; daysAgo >= 1; daysAgo--) {
      completions.add(
        _summary(
          userId,
          categories[daysAgo % categories.length],
          now: now,
          daysAgo: daysAgo,
          index: 100 - daysAgo,
        ),
      );
    }

    return completions..sort((a, b) => a.completedAt.compareTo(b.completedAt));
  }

  static CompletedMissionSummary _summary(
    String userId,
    MissionCategory category, {
    required DateTime now,
    required int daysAgo,
    required int index,
  }) {
    final day = now.subtract(Duration(days: daysAgo));
    return CompletedMissionSummary(
      missionInstanceId: 'seed-mission-$index',
      definitionId: 'seed-def-$index',
      userId: userId,
      category: category,
      difficulty: MissionDifficultyLevel.easy,
      baseXpHint: 15,
      resolvedDurationMinutes: 10,
      recoveryMission: false,
      completedAt: DateTime.utc(day.year, day.month, day.day, 9),
    );
  }
}
