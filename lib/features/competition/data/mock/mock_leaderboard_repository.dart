import '../../domain/entities/public_leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';

/// Mock mode never touches Supabase (spec section 8 — "preserve mock
/// mode") — and there is no such thing as a *confirmed* leaderboard
/// without a real server, so this returns empty lists rather than
/// fabricating plausible-looking confirmed data. Local, provisional
/// standing in mock mode continues to come entirely from the existing
/// `CompetitionRepository`/`CompetitionRankingEngine` path — this class
/// only stands in for the "confirmed" half, which mock mode simply
/// doesn't have.
class MockLeaderboardRepository implements LeaderboardRepository {
  const MockLeaderboardRepository();

  @override
  Future<List<PublicWeeklyLeaderboardEntry>> fetchWeeklyLeaderboard({
    required String seasonId,
    required int weekNumber,
    required String leagueId,
  }) async => const [];

  @override
  Future<List<PublicSeasonLeaderboardEntry>> fetchSeasonLeaderboard({
    required String seasonId,
    required String leagueId,
  }) async => const [];
}
