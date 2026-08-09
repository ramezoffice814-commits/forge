import 'package:flutter/foundation.dart';

import '../entities/leaderboard_entry.dart';

/// The full output of `CompetitionRankingEngine.rank` — the ordered
/// leaderboard plus the zone breakdown and any tie-break explanations, so
/// callers never have to re-derive zones from raw entries.
@immutable
class CompetitionRankingResult {
  const CompetitionRankingResult({
    required this.entries,
    required this.promotionZoneUserIds,
    required this.demotionZoneUserIds,
    required this.tieBreakNotes,
  });

  final List<LeaderboardEntry> entries;
  final Set<String> promotionZoneUserIds;
  final Set<String> demotionZoneUserIds;

  /// Populated only for a user whose rank relative to a score-tied
  /// neighbor was decided by a tie-break rule rather than score alone.
  final Map<String, String> tieBreakNotes;
}
