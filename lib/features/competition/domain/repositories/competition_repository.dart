import '../entities/competitive_completion_summary.dart';
import '../entities/hall_of_fame_record.dart';
import '../entities/league_definition.dart';
import '../entities/season_definition.dart';
import '../entities/weekly_competition_score.dart';
import '../services/competition_ranking_engine.dart';

/// Local-only storage for competition facts, catalogs, and the deterministic
/// mock population — never itself authoritative (see module trust-boundary
/// notes). A future backend is the only thing that can confirm a real rank
/// or season result.
abstract class CompetitionRepository {
  Future<SeasonDefinition> getCurrentSeason();
  Future<List<LeagueDefinition>> getLeagueDefinitions();

  Future<List<CompetitiveCompletionSummary>> completionsForUser(String userId);
  Future<void> recordCompletion(CompetitiveCompletionSummary summary);

  /// Persists a snapshot the caller wants remembered as "this week's
  /// current preview" — a hook for a future sync layer; reads never depend
  /// on this having been called, since a weekly score is always
  /// re-derivable from [completionsForUser].
  Future<void> saveLocalPreview(WeeklyCompetitionScore score);
  Future<List<WeeklyCompetitionScore>> weeklyScoresForUser(
    String userId,
    String seasonId,
  );

  /// The deterministic seeded mock population for one league/week,
  /// already shaped as ranking-ready participants — real per-user
  /// completion simulation for 30-50 fixture users would be far more
  /// machinery than a local mock phase needs (see `MockCompetitionCatalog`
  /// for how these are generated).
  Future<List<CompetitionRankingParticipant>> participantsForLeague({
    required String leagueId,
    required int weekNumber,
  });

  /// The single local user's current league assignment — seeded once, then
  /// only ever changed by [setCurrentLeagueIdForUser] (e.g. after a
  /// previewed promotion/demotion the user has acknowledged). Never
  /// inferred from lifetime XP or account age.
  Future<String> getCurrentLeagueIdForUser(String userId);
  Future<void> setCurrentLeagueIdForUser(String userId, String leagueId);

  /// Users protected from demotion this week (rookies, first week in a new
  /// league, etc.) within the given league/week.
  Future<Set<String>> protectedUserIdsForLeague(
    String leagueId,
    int weekNumber,
  );

  Future<List<HallOfFameRecord>> getHallOfFame();

  void clearForUser(String userId);
}
