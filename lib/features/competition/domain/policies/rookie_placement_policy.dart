import '../entities/league_definition.dart';
import '../entities/rookie_status.dart';
import 'competition_scoring_constants.dart';

/// New users must not immediately compete against established
/// high-performing users, and must not get an exaggerated newcomer bonus
/// either (spec section 6). Protection ends at whichever threshold is
/// reached first — 14 days since the first competitive completion, or
/// [CompetitionScoringConstants.rookieProtectionCompletions] competitive
/// completions — matching a standard "grace period: N days or M
/// activities, whichever comes first" onboarding shape.
abstract final class RookiePlacementPolicy {
  static RookieStatus statusFor({
    required DateTime firstCompetitiveCompletionAt,
    required int competitiveCompletionCount,
    required DateTime now,
  }) {
    final daysSince = now
        .toUtc()
        .difference(firstCompetitiveCompletionAt.toUtc())
        .inDays;
    final protectionEndsAt = firstCompetitiveCompletionAt.toUtc().add(
      const Duration(days: CompetitionScoringConstants.rookieProtectionDays),
    );

    final withinDayWindow =
        daysSince < CompetitionScoringConstants.rookieProtectionDays;
    final withinCompletionWindow =
        competitiveCompletionCount <
        CompetitionScoringConstants.rookieProtectionCompletions;
    final isRookie = withinDayWindow && withinCompletionWindow;

    final reason = isRookie
        ? 'Placement period — matched with newer participants while your '
              'starting league is determined'
        : !withinDayWindow
        ? 'Placement period ended after '
              '${CompetitionScoringConstants.rookieProtectionDays} days'
        : 'Placement period ended after '
              '${CompetitionScoringConstants.rookieProtectionCompletions} '
              'competitive completions';

    return RookieStatus(
      isRookie: isRookie,
      daysSinceFirstCompetitiveCompletion: daysSince,
      competitiveCompletionCount: competitiveCompletionCount,
      protectionEndsAt: protectionEndsAt,
      reason: reason,
    );
  }

  /// Assigns an initial league purely from early performance — never from
  /// lifetime XP or account age. [earlyScores] are per-mission competitive
  /// scores from the rookie's first completions; an empty list defaults to
  /// the floor league until real performance data exists.
  static RookiePlacementResult placeFor({
    required String userId,
    required List<LeagueDefinition> leagues,
    required List<double> earlyScores,
  }) {
    if (leagues.isEmpty) {
      throw ArgumentError('leagues must not be empty');
    }
    final sorted = [...leagues]
      ..sort((a, b) => a.minPlacementRating.compareTo(b.minPlacementRating));

    if (earlyScores.isEmpty) {
      return RookiePlacementResult(
        userId: userId,
        assignedLeagueId: sorted.first.id,
        placementRating: 0,
        basedOnCompletionCount: 0,
        reasons: const [
          'No competitive completions yet — starting in the floor league',
        ],
      );
    }

    final averageScore =
        earlyScores.reduce((a, b) => a + b) / earlyScores.length;
    final placementRating = averageScore.round();

    var assigned = sorted.first;
    for (final league in sorted) {
      if (placementRating >= league.minPlacementRating) {
        assigned = league;
      }
    }

    return RookiePlacementResult(
      userId: userId,
      assignedLeagueId: assigned.id,
      placementRating: placementRating,
      basedOnCompletionCount: earlyScores.length,
      reasons: [
        'Placed from ${earlyScores.length} early completion(s) — '
            'lifetime account age was not a factor',
      ],
    );
  }
}
