import 'package:flutter/foundation.dart';

/// The outcome of rolling one season into the next. Every "preserved"
/// field here documents a promise this module must never break — lifetime
/// progression is never touched by a season reset.
@immutable
class SeasonTransitionResult {
  const SeasonTransitionResult({
    required this.previousSeasonId,
    required this.newSeasonId,
    required this.weeklyScoresReset,
    required this.seasonScoreReset,
    required this.lifetimeXpPreserved,
    required this.achievementsPreserved,
    required this.hallOfFameRecordsAdded,
    required this.transitionedAt,
  });

  final String previousSeasonId;
  final String newSeasonId;

  final bool weeklyScoresReset;
  final bool seasonScoreReset;

  /// Always `true` — asserted as a field (not just a doc comment) so tests
  /// can check the transition result itself, not just its side effects.
  final bool lifetimeXpPreserved;
  final bool achievementsPreserved;

  final int hallOfFameRecordsAdded;
  final DateTime transitionedAt;
}
