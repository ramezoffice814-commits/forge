import 'package:flutter/foundation.dart';

import '../enums/league_tier.dart';

/// A catalog entry describing one league's rules — never hardcoded
/// if/else branching on tier; `CompetitionRankingEngine`/
/// `LeagueMovementPolicy` only ever read these fields.
@immutable
class LeagueDefinition {
  const LeagueDefinition({
    required this.id,
    required this.name,
    required this.tier,
    required this.minPlacementRating,
    required this.maxGroupSize,
    required this.promotionCount,
    required this.demotionCount,
    required this.protectedPlacementDays,
    required this.visualTier,
    required this.active,
  });

  final String id;
  final String name;
  final LeagueTier tier;

  /// The minimum rookie-placement rating that lands a new participant in
  /// this league — see `RookiePlacementPolicy`.
  final int minPlacementRating;

  final int maxGroupSize;

  /// `0` for the ceiling league (nothing to promote into).
  final int promotionCount;

  /// `0` for the floor league (nothing to demote into).
  final int demotionCount;

  final int protectedPlacementDays;

  /// Display-only ordinal for badge art/theming — intentionally separate
  /// from `tier.index` so visual treatment can diverge from competitive
  /// ordering later without a domain change.
  final int visualTier;

  final bool active;
}
