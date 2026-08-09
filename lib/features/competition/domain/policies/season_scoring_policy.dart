import '../entities/season_score.dart';
import '../entities/weekly_competition_score.dart';

/// Best-N-of-M week aggregation (spec section 15) — never a plain sum of
/// every week, so a holiday, illness, or a slightly-late join doesn't sink
/// an otherwise strong season. [countedWeeks] is configurable per season
/// via [countedWeekCount], not hardcoded.
abstract final class SeasonScoringPolicy {
  static SeasonScore aggregate({
    required String userId,
    required String seasonId,
    required List<WeeklyCompetitionScore> weeklyScores,
    required int countedWeekCount,
  }) {
    final sorted = [...weeklyScores]
      ..sort((a, b) => b.cappedScore.compareTo(a.cappedScore));

    final counted = sorted.take(countedWeekCount).toList();
    final dropped = sorted.skip(countedWeekCount).toList();

    final total = counted.fold<double>(0, (sum, w) => sum + w.cappedScore);

    return SeasonScore(
      userId: userId,
      seasonId: seasonId,
      countedWeeks: counted.map((w) => w.weekNumber).toList()..sort(),
      droppedWeeks: dropped.map((w) => w.weekNumber).toList()..sort(),
      totalSeasonScore: total,
      scoringRule:
          'Best $countedWeekCount of ${weeklyScores.length} weeks '
          'played',
    );
  }
}
