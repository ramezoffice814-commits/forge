import 'package:flutter/foundation.dart';

/// One row of the confirmed weekly leaderboard — mirrors
/// `competition_public_weekly_leaderboard` (see supabase/migrations/
/// 20260819090000_season_finalization.sql /
/// 20260820090300_leaderboard_user_id.sql) exactly, field for field.
/// Every field here is already public-safe by construction (same
/// discipline as the existing local `LeaderboardEntry` — see that
/// class's own doc comment); this type additionally carries [userId]
/// so the UI can identify "you" (spec section 9).
@immutable
class PublicWeeklyLeaderboardEntry {
  const PublicWeeklyLeaderboardEntry({
    required this.userId,
    required this.seasonId,
    required this.weekNumber,
    required this.leagueId,
    required this.leagueName,
    required this.rank,
    required this.confirmedScore,
    required this.promotionStatus,
    required this.displayName,
    this.avatarPath,
  });

  final String userId;
  final String seasonId;
  final int weekNumber;
  final String leagueId;
  final String leagueName;
  final int rank;
  final double confirmedScore;

  /// One of `promotionZone` / `safeZone` / `demotionZone` — the same
  /// values `forge_finalize_season_week` writes.
  final String promotionStatus;

  final String displayName;
  final String? avatarPath;
}

/// One row of the confirmed season leaderboard — mirrors
/// `competition_public_season_leaderboard`.
@immutable
class PublicSeasonLeaderboardEntry {
  const PublicSeasonLeaderboardEntry({
    required this.userId,
    required this.seasonId,
    required this.finalLeagueId,
    required this.leagueName,
    required this.rankInLeague,
    required this.confirmedScore,
    required this.promoted,
    required this.demoted,
    required this.displayName,
    this.avatarPath,
  });

  final String userId;
  final String seasonId;
  final String finalLeagueId;
  final String leagueName;
  final int rankInLeague;
  final double confirmedScore;
  final bool promoted;
  final bool demoted;
  final String displayName;
  final String? avatarPath;
}
