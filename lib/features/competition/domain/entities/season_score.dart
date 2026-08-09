import 'package:flutter/foundation.dart';

/// A season's capped/best-weeks aggregation — see `SeasonScoringPolicy`.
/// Never a plain sum of every week, so a holiday, illness, or late join
/// doesn't wreck an otherwise-strong season.
@immutable
class SeasonScore {
  const SeasonScore({
    required this.userId,
    required this.seasonId,
    required this.countedWeeks,
    required this.droppedWeeks,
    required this.totalSeasonScore,
    required this.scoringRule,
    this.provisionalOnly = true,
  });

  final String userId;
  final String seasonId;

  /// Week numbers that counted toward [totalSeasonScore].
  final List<int> countedWeeks;

  /// Week numbers that existed but were dropped by the best-N-of-M rule.
  final List<int> droppedWeeks;

  final double totalSeasonScore;

  /// Human-readable rule description, e.g. "Best 6 of 8 weeks" — kept as
  /// text (not just a config number) so it can be surfaced directly in the
  /// season UI without re-deriving it.
  final String scoringRule;

  final bool provisionalOnly;
}
