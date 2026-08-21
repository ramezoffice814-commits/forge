import '../../domain/entities/public_leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';

/// Pure row-mapping functions, split out from
/// [SupabaseLeaderboardRepository] so the malformed-row-rejection logic
/// is directly unit-testable with plain `Map` fixtures — no
/// `SupabaseClient`, no network (spec section 23: "confirmed leaderboard
/// mapping").

PublicWeeklyLeaderboardEntry parseWeeklyLeaderboardRow(
  Map<String, dynamic> row,
) {
  return PublicWeeklyLeaderboardEntry(
    userId: requireString(row, 'user_id'),
    seasonId: requireString(row, 'season_id'),
    weekNumber: requireInt(row, 'week_number'),
    leagueId: requireString(row, 'league_id'),
    leagueName: requireString(row, 'league_name'),
    rank: requireInt(row, 'rank'),
    confirmedScore: requireNum(row, 'confirmed_score').toDouble(),
    promotionStatus: requireString(row, 'promotion_status'),
    displayName: requireString(row, 'display_name'),
    avatarPath: row['avatar_path'] as String?,
  );
}

PublicSeasonLeaderboardEntry parseSeasonLeaderboardRow(
  Map<String, dynamic> row,
) {
  return PublicSeasonLeaderboardEntry(
    userId: requireString(row, 'user_id'),
    seasonId: requireString(row, 'season_id'),
    finalLeagueId: requireString(row, 'final_league_id'),
    leagueName: requireString(row, 'league_name'),
    rankInLeague: requireInt(row, 'rank_in_league'),
    confirmedScore: requireNum(row, 'confirmed_score').toDouble(),
    promoted: requireBool(row, 'promoted'),
    demoted: requireBool(row, 'demoted'),
    displayName: requireString(row, 'display_name'),
    avatarPath: row['avatar_path'] as String?,
  );
}

String requireString(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String) {
    throw MalformedLeaderboardRowException(
      'Expected string field "$key", got: $value',
    );
  }
  return value;
}

int requireInt(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw MalformedLeaderboardRowException(
    'Expected numeric field "$key", got: $value',
  );
}

num requireNum(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is num) return value;
  // Postgres numeric columns can arrive over PostgREST as a numeric
  // string in some client configurations — accept that shape too
  // rather than reject a value that is genuinely well-formed.
  if (value is String) {
    final parsed = num.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw MalformedLeaderboardRowException(
    'Expected numeric field "$key", got: $value',
  );
}

bool requireBool(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! bool) {
    throw MalformedLeaderboardRowException(
      'Expected boolean field "$key", got: $value',
    );
  }
  return value;
}
