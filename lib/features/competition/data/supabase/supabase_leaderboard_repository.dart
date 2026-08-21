import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../domain/entities/public_leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import 'leaderboard_row_mapper.dart';

/// Real, live-mode implementation — reads only the two public-safe
/// views (`competition_public_weekly_leaderboard`/
/// `competition_public_season_leaderboard`), never a private table
/// directly. Row parsing itself lives in `leaderboard_row_mapper.dart`
/// as plain, network-free functions — this class is just the Supabase
/// query + delegation to them.
class SupabaseLeaderboardRepository implements LeaderboardRepository {
  const SupabaseLeaderboardRepository(this._client);

  final supa.SupabaseClient _client;

  @override
  Future<List<PublicWeeklyLeaderboardEntry>> fetchWeeklyLeaderboard({
    required String seasonId,
    required int weekNumber,
    required String leagueId,
  }) async {
    final rows = await _client
        .from('competition_public_weekly_leaderboard')
        .select()
        .eq('season_id', seasonId)
        .eq('week_number', weekNumber)
        .eq('league_id', leagueId)
        .order('rank');

    return rows.map(parseWeeklyLeaderboardRow).toList(growable: false);
  }

  @override
  Future<List<PublicSeasonLeaderboardEntry>> fetchSeasonLeaderboard({
    required String seasonId,
    required String leagueId,
  }) async {
    final rows = await _client
        .from('competition_public_season_leaderboard')
        .select()
        .eq('season_id', seasonId)
        .eq('final_league_id', leagueId)
        .order('rank_in_league');

    return rows.map(parseSeasonLeaderboardRow).toList(growable: false);
  }
}
