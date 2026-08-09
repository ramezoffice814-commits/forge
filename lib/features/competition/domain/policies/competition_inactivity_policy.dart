import 'competition_scoring_constants.dart';

/// Inactivity is never punished beyond letting the weekly score naturally
/// fall — no lifetime XP subtraction, no manipulative decay copy (spec
/// section 20). After sustained inactivity a participant simply stops
/// occupying a slot in the active leaderboard pool.
abstract final class CompetitionInactivityPolicy {
  static bool shouldExcludeFromActivePool({
    required int consecutiveInactiveWeeks,
  }) {
    return consecutiveInactiveWeeks >=
        CompetitionScoringConstants.inactivityExclusionWeeks;
  }
}
