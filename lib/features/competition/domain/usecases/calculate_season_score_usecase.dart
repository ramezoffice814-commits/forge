import '../entities/season_score.dart';
import '../policies/season_scoring_policy.dart';
import '../repositories/competition_repository.dart';

/// Best-N-of-M aggregation for one user's season, reading whatever weekly
/// scores have actually been recorded so far — a season in progress simply
/// has fewer weeks to choose from, never zero-filled placeholders for
/// weeks that haven't happened yet (spec section 15's "late join" case).
class CalculateSeasonScoreUseCase {
  const CalculateSeasonScoreUseCase(this._repository);

  final CompetitionRepository _repository;

  Future<SeasonScore> call({
    required String userId,
    required String seasonId,
    required int countedWeekCount,
  }) async {
    final weeklyScores = await _repository.weeklyScoresForUser(
      userId,
      seasonId,
    );

    return SeasonScoringPolicy.aggregate(
      userId: userId,
      seasonId: seasonId,
      weeklyScores: weeklyScores,
      countedWeekCount: countedWeekCount,
    );
  }
}
