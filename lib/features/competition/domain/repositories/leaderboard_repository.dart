import '../entities/public_leaderboard_entry.dart';

/// Thrown when a raw leaderboard row doesn't match the expected shape —
/// a malformed row is dropped/rejected, never guessed at or silently
/// coerced (spec section 9: "reject malformed server rows").
class MalformedLeaderboardRowException implements Exception {
  const MalformedLeaderboardRowException(this.message);

  final String message;

  @override
  String toString() => 'MalformedLeaderboardRowException: $message';
}

/// The one seam Flutter widgets depend on for confirmed leaderboard
/// data — never a raw Supabase row map (spec section 9: "do not couple
/// widgets directly to Supabase row maps"). [MockLeaderboardRepository]
/// (mock mode) and [SupabaseLeaderboardRepository] (live mode) are the
/// only two implementations; both return the exact same domain types.
abstract class LeaderboardRepository {
  Future<List<PublicWeeklyLeaderboardEntry>> fetchWeeklyLeaderboard({
    required String seasonId,
    required int weekNumber,
    required String leagueId,
  });

  Future<List<PublicSeasonLeaderboardEntry>> fetchSeasonLeaderboard({
    required String seasonId,
    required String leagueId,
  });
}
