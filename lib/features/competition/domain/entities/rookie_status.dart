import 'package:flutter/foundation.dart';

/// Whether a participant is still within the protected placement window —
/// see `RookiePlacementPolicy` for the exact exit rule (14 days OR N
/// competitive completions, whichever comes first).
@immutable
class RookieStatus {
  const RookieStatus({
    required this.isRookie,
    required this.daysSinceFirstCompetitiveCompletion,
    required this.competitiveCompletionCount,
    required this.protectionEndsAt,
    required this.reason,
  });

  final bool isRookie;
  final int daysSinceFirstCompetitiveCompletion;
  final int competitiveCompletionCount;

  /// The instant protection would end purely from the day-based rule —
  /// still meaningful even after the completion-count rule has already
  /// ended protection, for display ("placement ends in N days or M
  /// completions, whichever comes first").
  final DateTime protectionEndsAt;

  final String reason;
}

/// The outcome of placing a rookie into their first league, derived from
/// early performance rather than lifetime XP or account age.
@immutable
class RookiePlacementResult {
  const RookiePlacementResult({
    required this.userId,
    required this.assignedLeagueId,
    required this.placementRating,
    required this.basedOnCompletionCount,
    required this.reasons,
  });

  final String userId;
  final String assignedLeagueId;
  final int placementRating;

  /// How many early completions the placement rating was derived from —
  /// surfaced so the UI/tests can distinguish "placed from real
  /// performance" from "not enough data yet, defaulted to the floor
  /// league".
  final int basedOnCompletionCount;

  final List<String> reasons;
}
