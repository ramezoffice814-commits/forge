import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/domain/entities/public_leaderboard_entry.dart';
import 'package:forge/features/competition/domain/repositories/leaderboard_repository.dart';
import 'package:forge/features/competition/domain/services/cached_leaderboard_fetch.dart';

class ScriptedLeaderboardRepository implements LeaderboardRepository {
  ScriptedLeaderboardRepository(this._weeklyScript);

  final List<Object>
  _weeklyScript; // a List<PublicWeeklyLeaderboardEntry> or an Exception.
  int callCount = 0;

  @override
  Future<List<PublicWeeklyLeaderboardEntry>> fetchWeeklyLeaderboard({
    required String seasonId,
    required int weekNumber,
    required String leagueId,
  }) async {
    final outcome = _weeklyScript[callCount];
    callCount += 1;
    if (outcome is Exception) throw outcome;
    return outcome as List<PublicWeeklyLeaderboardEntry>;
  }

  @override
  Future<List<PublicSeasonLeaderboardEntry>> fetchSeasonLeaderboard({
    required String seasonId,
    required String leagueId,
  }) async => const [];
}

PublicWeeklyLeaderboardEntry entry(String userId, int rank) {
  return PublicWeeklyLeaderboardEntry(
    userId: userId,
    seasonId: 'season-1',
    weekNumber: 1,
    leagueId: 'league-1',
    leagueName: 'Iron',
    rank: rank,
    confirmedScore: 10.0,
    promotionStatus: 'safeZone',
    displayName: 'User',
  );
}

void main() {
  test('a successful fetch is reported fresh and cached for later', () async {
    final repo = ScriptedLeaderboardRepository([
      [entry('u1', 1)],
    ]);
    final fetcher = CachedLeaderboardFetcher(repo);

    final result = await fetcher.fetchWeekly(
      seasonId: 's',
      weekNumber: 1,
      leagueId: 'l',
    );

    expect(result.freshness, LeaderboardFreshness.fresh);
    expect(result.entries, hasLength(1));
    expect(result.fetchedAt, isNotNull);
  });

  test(
    'a failed fetch with no prior cache is reported unavailable, not an exception',
    () async {
      final repo = ScriptedLeaderboardRepository([Exception('offline')]);
      final fetcher = CachedLeaderboardFetcher(repo);

      final result = await fetcher.fetchWeekly(
        seasonId: 's',
        weekNumber: 1,
        leagueId: 'l',
      );

      expect(result.freshness, LeaderboardFreshness.unavailable);
      expect(result.entries, isEmpty);
    },
  );

  test(
    'a failed fetch after a successful one falls back to the cached result, marked stale',
    () async {
      final repo = ScriptedLeaderboardRepository([
        [entry('u1', 1)],
        Exception('offline'),
      ]);
      final fetcher = CachedLeaderboardFetcher(repo);

      final first = await fetcher.fetchWeekly(
        seasonId: 's',
        weekNumber: 1,
        leagueId: 'l',
      );
      expect(first.freshness, LeaderboardFreshness.fresh);

      final second = await fetcher.fetchWeekly(
        seasonId: 's',
        weekNumber: 1,
        leagueId: 'l',
      );
      expect(second.freshness, LeaderboardFreshness.cachedStale);
      expect(second.entries, hasLength(1));
      expect(second.entries.single.userId, 'u1');
    },
  );
}
