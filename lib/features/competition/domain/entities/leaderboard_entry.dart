import 'package:flutter/foundation.dart';

import '../enums/promotion_status.dart';

/// The only shape a leaderboard is ever allowed to render — every field is
/// public-safe by construction. See module privacy rules: never add a
/// field here for email, private habits, rejection reasons, reflections,
/// health/accessibility tags, or detailed mission history. Recovery status
/// is deliberately absent for the same reason (a recovery user must never
/// be publicly labeled as such).
@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.league,
    required this.rank,
    required this.weeklyScore,
    required this.activeDays,
    required this.promotionStatus,
    this.provisionalOnly = true,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String league;
  final int rank;
  final double weeklyScore;
  final int activeDays;
  final PromotionStatus promotionStatus;
  final bool provisionalOnly;
}
