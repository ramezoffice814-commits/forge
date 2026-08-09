import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/domain/entities/weekly_competition_score.dart';
import 'package:forge/features/competition/domain/policies/season_scoring_policy.dart';

WeeklyCompetitionScore _week(int number, double score) {
  return WeeklyCompetitionScore(
    userId: 'u1',
    seasonId: 'season-1',
    weekNumber: number,
    rawScore: score,
    cappedScore: score,
    completedMissionCount: 5,
    activeDays: 4,
    categoriesUsed: const {},
    integrityFlags: const {},
    scoreBreakdown: const {},
  );
}

void main() {
  test('only the best N weeks count toward the total', () {
    final weeks = [_week(1, 100), _week(2, 50), _week(3, 200), _week(4, 10)];
    final result = SeasonScoringPolicy.aggregate(
      userId: 'u1',
      seasonId: 'season-1',
      weeklyScores: weeks,
      countedWeekCount: 2,
    );
    expect(result.countedWeeks, [1, 3]);
    expect(result.droppedWeeks, [2, 4]);
    expect(result.totalSeasonScore, 300);
  });

  test('a season with fewer weeks than the counted-week target counts all '
      'of them, never fabricating a zero week for a late join', () {
    final weeks = [_week(1, 40), _week(2, 60)];
    final result = SeasonScoringPolicy.aggregate(
      userId: 'u1',
      seasonId: 'season-1',
      weeklyScores: weeks,
      countedWeekCount: 6,
    );
    expect(result.countedWeeks, [1, 2]);
    expect(result.droppedWeeks, isEmpty);
    expect(result.totalSeasonScore, 100);
  });

  test('no weeks played produces a zero total, not an error', () {
    final result = SeasonScoringPolicy.aggregate(
      userId: 'u1',
      seasonId: 'season-1',
      weeklyScores: const [],
      countedWeekCount: 6,
    );
    expect(result.totalSeasonScore, 0);
    expect(result.countedWeeks, isEmpty);
  });

  test('every result is marked provisionalOnly', () {
    final result = SeasonScoringPolicy.aggregate(
      userId: 'u1',
      seasonId: 'season-1',
      weeklyScores: [_week(1, 10)],
      countedWeekCount: 6,
    );
    expect(result.provisionalOnly, isTrue);
  });
}
