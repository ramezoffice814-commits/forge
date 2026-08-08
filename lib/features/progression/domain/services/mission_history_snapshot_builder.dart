import '../../../missions/domain/enums/mission_category.dart';
import '../../../missions/domain/enums/mission_difficulty_level.dart';
import '../entities/completed_mission_summary.dart';
import '../entities/mission_history_snapshot.dart';

/// Builds a [MissionHistorySnapshot] purely from an ordered list of
/// [CompletedMissionSummary] — the same list always produces the same
/// snapshot, which is what lets every policy that reads it stay
/// deterministic in turn.
abstract final class MissionHistorySnapshotBuilder {
  static MissionHistorySnapshot build(
    List<CompletedMissionSummary> completions, {
    required DateTime asOf,
  }) {
    if (completions.isEmpty) return const MissionHistorySnapshot.empty();

    final sorted = [...completions]
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    final byCategory = <MissionCategory, int>{};
    final byDefinition = <String, int>{};
    final categoriesTried = <MissionCategory>{};
    var advancedOrChallenging = 0;
    var recoveryCount = 0;

    for (final summary in sorted) {
      byCategory[summary.category] = (byCategory[summary.category] ?? 0) + 1;
      byDefinition[summary.definitionId] =
          (byDefinition[summary.definitionId] ?? 0) + 1;
      categoriesTried.add(summary.category);
      if (summary.difficulty.isAtLeast(MissionDifficultyLevel.challenging)) {
        advancedOrChallenging += 1;
      }
      if (summary.recoveryMission) recoveryCount += 1;
    }

    final lastCompletedAt = sorted.last.completedAt;
    final daysSinceLast = asOf.difference(lastCompletedAt).inDays;

    final completionDays =
        sorted
            .map(
              (s) => DateTime.utc(
                s.completedAt.year,
                s.completedAt.month,
                s.completedAt.day,
              ),
            )
            .toSet()
            .toList()
          ..sort();

    final streaks = _streaks(completionDays, asOf: asOf);

    // A gap of 3+ days before the most recent completion counts as
    // "returning" — but only when there was a completion before that gap to
    // return *from* (a brand-new user's first mission isn't a comeback).
    var justReturned = false;
    if (completionDays.length >= 2) {
      final gap = completionDays.last
          .difference(completionDays[completionDays.length - 2])
          .inDays;
      justReturned = gap >= 3;
    }

    return MissionHistorySnapshot(
      totalCompletions: sorted.length,
      completionsByCategory: byCategory,
      completionsByDefinitionId: byDefinition,
      categoriesTried: categoriesTried,
      currentStreakDays: streaks.$1,
      longestStreakDays: streaks.$2,
      daysSinceLastCompletion: daysSinceLast,
      advancedOrChallengingCompletions: advancedOrChallenging,
      recoveryCompletions: recoveryCount,
      justReturnedFromInactivity: justReturned,
    );
  }

  /// Returns (currentStreakDays, longestStreakDays) from a sorted, deduped
  /// list of UTC calendar days with at least one completion. The current
  /// streak counts back from [asOf]'s calendar day (or yesterday, so
  /// finishing today doesn't reset a streak still "in progress").
  static (int, int) _streaks(
    List<DateTime> completionDays, {
    required DateTime asOf,
  }) {
    if (completionDays.isEmpty) return (0, 0);

    var longest = 1;
    var running = 1;
    for (var i = 1; i < completionDays.length; i++) {
      final gap = completionDays[i].difference(completionDays[i - 1]).inDays;
      if (gap == 1) {
        running += 1;
      } else if (gap > 1) {
        running = 1;
      }
      if (running > longest) longest = running;
    }

    final today = DateTime.utc(asOf.year, asOf.month, asOf.day);
    final gapToToday = today.difference(completionDays.last).inDays;
    if (gapToToday > 1) return (0, longest);

    var current = 1;
    for (var i = completionDays.length - 1; i > 0; i--) {
      final gap = completionDays[i].difference(completionDays[i - 1]).inDays;
      if (gap == 1) {
        current += 1;
      } else {
        break;
      }
    }
    return (current, longest);
  }
}
