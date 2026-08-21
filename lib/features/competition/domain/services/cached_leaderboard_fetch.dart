import 'package:flutter/foundation.dart';

import '../entities/public_leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';

/// Whether a fetched leaderboard result is genuinely fresh, a cached
/// fallback because the live fetch just failed, or unavailable
/// entirely (spec section 9: "support loading/offline/cached state").
enum LeaderboardFreshness { fresh, cachedStale, unavailable }

@immutable
class LeaderboardFetchResult<T> {
  const LeaderboardFetchResult({
    required this.entries,
    required this.freshness,
    this.fetchedAt,
  });

  final List<T> entries;
  final LeaderboardFreshness freshness;

  /// When [entries] was actually fetched from the server — `null` only
  /// for [LeaderboardFreshness.unavailable].
  final DateTime? fetchedAt;
}

/// Wraps a [LeaderboardRepository] with a simple last-good-result cache
/// per query key — never a persistence layer, just an in-memory
/// fallback so a transient offline moment doesn't blank the screen. A
/// cache hit is always reported as [LeaderboardFreshness.cachedStale],
/// never silently presented as fresh.
class CachedLeaderboardFetcher {
  CachedLeaderboardFetcher(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LeaderboardRepository _repository;
  final DateTime Function() _now;

  final Map<String, (List<PublicWeeklyLeaderboardEntry>, DateTime)>
  _weeklyCache = {};
  final Map<String, (List<PublicSeasonLeaderboardEntry>, DateTime)>
  _seasonCache = {};

  String _weeklyKey(String seasonId, int weekNumber, String leagueId) =>
      '$seasonId:$weekNumber:$leagueId';
  String _seasonKey(String seasonId, String leagueId) => '$seasonId:$leagueId';

  Future<LeaderboardFetchResult<PublicWeeklyLeaderboardEntry>> fetchWeekly({
    required String seasonId,
    required int weekNumber,
    required String leagueId,
  }) async {
    final key = _weeklyKey(seasonId, weekNumber, leagueId);
    try {
      final entries = await _repository.fetchWeeklyLeaderboard(
        seasonId: seasonId,
        weekNumber: weekNumber,
        leagueId: leagueId,
      );
      final fetchedAt = _now();
      _weeklyCache[key] = (entries, fetchedAt);
      return LeaderboardFetchResult(
        entries: entries,
        freshness: LeaderboardFreshness.fresh,
        fetchedAt: fetchedAt,
      );
    } catch (_) {
      final cached = _weeklyCache[key];
      if (cached == null) {
        return const LeaderboardFetchResult(
          entries: [],
          freshness: LeaderboardFreshness.unavailable,
        );
      }
      return LeaderboardFetchResult(
        entries: cached.$1,
        freshness: LeaderboardFreshness.cachedStale,
        fetchedAt: cached.$2,
      );
    }
  }

  Future<LeaderboardFetchResult<PublicSeasonLeaderboardEntry>> fetchSeason({
    required String seasonId,
    required String leagueId,
  }) async {
    final key = _seasonKey(seasonId, leagueId);
    try {
      final entries = await _repository.fetchSeasonLeaderboard(
        seasonId: seasonId,
        leagueId: leagueId,
      );
      final fetchedAt = _now();
      _seasonCache[key] = (entries, fetchedAt);
      return LeaderboardFetchResult(
        entries: entries,
        freshness: LeaderboardFreshness.fresh,
        fetchedAt: fetchedAt,
      );
    } catch (_) {
      final cached = _seasonCache[key];
      if (cached == null) {
        return const LeaderboardFetchResult(
          entries: [],
          freshness: LeaderboardFreshness.unavailable,
        );
      }
      return LeaderboardFetchResult(
        entries: cached.$1,
        freshness: LeaderboardFreshness.cachedStale,
        fetchedAt: cached.$2,
      );
    }
  }
}
