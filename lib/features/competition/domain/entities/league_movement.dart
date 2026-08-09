import 'package:flutter/foundation.dart';

import '../enums/promotion_status.dart';

/// The result of evaluating one participant's end-of-week movement — never
/// applied automatically in this local/mock phase (there is no backend to
/// confirm it), only computed and previewed. See module trust-boundary
/// notes: no local `ConfirmedRank`/movement event is ever created.
@immutable
class LeagueMovementEvaluation {
  const LeagueMovementEvaluation({
    required this.userId,
    required this.currentLeagueId,
    required this.zone,
    this.targetLeagueId,
    required this.rank,
    required this.protected,
    this.tieBreakReason,
    required this.reasons,
    required this.ruleVersion,
    this.provisionalOnly = true,
  });

  final String userId;
  final String currentLeagueId;
  final PromotionStatus zone;

  /// `null` when [zone] is `safeZone`, or when protection/floor/ceiling
  /// rules keep the participant in [currentLeagueId] regardless of zone.
  final String? targetLeagueId;

  final int rank;

  /// `true` if rookie/new-league/inactivity protection suppressed a
  /// demotion that would otherwise apply.
  final bool protected;

  /// Populated only when this participant's zone was decided by a
  /// tie-break rather than score alone — see `LeagueMovementPolicy`'s
  /// documented tie-break order.
  final String? tieBreakReason;

  final List<String> reasons;
  final int ruleVersion;
  final bool provisionalOnly;
}

/// The UI-facing preview shown on the Rank page — deliberately worded as a
/// preview ("Currently in promotion zone"), never a guarantee.
@immutable
class LeagueMovementPreview {
  const LeagueMovementPreview({
    required this.promotionThresholdRank,
    required this.demotionThresholdRank,
    required this.currentRank,
    required this.zone,
    required this.pointsToNextRank,
  });

  final int promotionThresholdRank;
  final int demotionThresholdRank;
  final int currentRank;
  final PromotionStatus zone;

  /// Score points needed to overtake the participant immediately above —
  /// `0` when already at rank 1.
  final double pointsToNextRank;
}
