import '../../domain/entities/competitive_completion_summary.dart';
import '../../domain/entities/hall_of_fame_record.dart';
import '../../domain/entities/league_definition.dart';
import '../../domain/entities/season_definition.dart';
import '../../domain/entities/weekly_competition_score.dart';
import '../../domain/repositories/competition_repository.dart';
import '../../domain/services/competition_ranking_engine.dart';
import '../mock/league_catalog.dart';
import '../mock/mock_competition_catalog.dart';

/// The only repository implementation this phase ships — in-memory,
/// process-lifetime storage, same reasoning as
/// `InMemoryProgressionRepository`: no native persistence dependency, and
/// nothing here is ever treated as a source of truth beyond "what this
/// device currently believes locally."
class InMemoryCompetitionRepository implements CompetitionRepository {
  final Map<String, List<CompetitiveCompletionSummary>> _completionsByUser = {};

  // Key: 'userId|seasonId|weekNumber'.
  final Map<String, WeeklyCompetitionScore> _weeklyPreviews = {};

  final Map<String, String> _currentLeagueByUser = {};

  String _weeklyKey(String userId, String seasonId, int weekNumber) =>
      '$userId|$seasonId|$weekNumber';

  @override
  Future<SeasonDefinition> getCurrentSeason() async {
    return MockCompetitionCatalog.currentSeason();
  }

  @override
  Future<List<LeagueDefinition>> getLeagueDefinitions() async {
    return LeagueCatalog.leagues;
  }

  @override
  Future<List<CompetitiveCompletionSummary>> completionsForUser(
    String userId,
  ) async {
    return List.unmodifiable(_completionsByUser[userId] ?? const []);
  }

  @override
  Future<void> recordCompletion(CompetitiveCompletionSummary summary) async {
    _completionsByUser.putIfAbsent(summary.userId, () => []).add(summary);
  }

  @override
  Future<void> saveLocalPreview(WeeklyCompetitionScore score) async {
    _weeklyPreviews[_weeklyKey(
          score.userId,
          score.seasonId,
          score.weekNumber,
        )] =
        score;
  }

  @override
  Future<List<WeeklyCompetitionScore>> weeklyScoresForUser(
    String userId,
    String seasonId,
  ) async {
    return _weeklyPreviews.values
        .where((score) => score.userId == userId && score.seasonId == seasonId)
        .toList();
  }

  @override
  Future<List<CompetitionRankingParticipant>> participantsForLeague({
    required String leagueId,
    required int weekNumber,
  }) async {
    return MockCompetitionCatalog.participantsForLeague(
      leagueId: leagueId,
      weekNumber: weekNumber,
    );
  }

  @override
  Future<String> getCurrentLeagueIdForUser(String userId) async {
    return _currentLeagueByUser[userId] ?? LeagueCatalog.leagues.first.id;
  }

  @override
  Future<void> setCurrentLeagueIdForUser(String userId, String leagueId) async {
    _currentLeagueByUser[userId] = leagueId;
  }

  @override
  Future<Set<String>> protectedUserIdsForLeague(
    String leagueId,
    int weekNumber,
  ) async {
    return MockCompetitionCatalog.protectedUserIds(leagueId, weekNumber);
  }

  @override
  Future<List<HallOfFameRecord>> getHallOfFame() async {
    return MockCompetitionCatalog.hallOfFame();
  }

  @override
  void clearForUser(String userId) {
    _completionsByUser.remove(userId);
    _currentLeagueByUser.remove(userId);
    _weeklyPreviews.removeWhere((key, value) => value.userId == userId);
  }
}
