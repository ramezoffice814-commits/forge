import 'package:flutter/foundation.dart';

import '../entities/competition_week.dart';
import '../entities/season_definition.dart';
import '../entities/season_score.dart';
import '../policies/competition_calendar.dart';
import '../policies/competition_scoring_constants.dart';
import '../repositories/competition_repository.dart';
import 'calculate_season_score_usecase.dart';

@immutable
class SeasonProgressSnapshot {
  const SeasonProgressSnapshot({
    required this.season,
    required this.currentWeek,
    required this.seasonScore,
    required this.weekProgressFraction,
  });

  final SeasonDefinition season;
  final CompetitionWeek currentWeek;
  final SeasonScore seasonScore;

  /// `currentWeek.weekNumber / season.weekCount`, clamped to `[0, 1]` —
  /// how far through the season's *weeks* the user is, independent of
  /// score.
  final double weekProgressFraction;
}

class GetSeasonProgressUseCase {
  const GetSeasonProgressUseCase(this._repository);

  final CompetitionRepository _repository;

  Future<SeasonProgressSnapshot> call(
    String userId, {
    required DateTime now,
  }) async {
    final season = await _repository.getCurrentSeason();
    final weeks = CompetitionCalendar.weeksFor(season, now);
    final currentWeek =
        CompetitionCalendar.currentWeekFor(season, now) ?? weeks.last;

    final countedWeekCount =
        season.weekCount < CompetitionScoringConstants.defaultSeasonCountedWeeks
        ? season.weekCount
        : CompetitionScoringConstants.defaultSeasonCountedWeeks;

    final seasonScore = await CalculateSeasonScoreUseCase(_repository)(
      userId: userId,
      seasonId: season.id,
      countedWeekCount: countedWeekCount,
    );

    return SeasonProgressSnapshot(
      season: season,
      currentWeek: currentWeek,
      seasonScore: seasonScore,
      weekProgressFraction: (currentWeek.weekNumber / season.weekCount).clamp(
        0.0,
        1.0,
      ),
    );
  }
}
