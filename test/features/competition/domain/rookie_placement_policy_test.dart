import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/domain/entities/league_definition.dart';
import 'package:forge/features/competition/domain/enums/league_tier.dart';
import 'package:forge/features/competition/domain/policies/competition_scoring_constants.dart';
import 'package:forge/features/competition/domain/policies/rookie_placement_policy.dart';

void main() {
  final start = DateTime.utc(2026, 8, 1);

  const leagues = [
    LeagueDefinition(
      id: 'league-ember',
      name: 'Ember',
      tier: LeagueTier.ember,
      minPlacementRating: 0,
      maxGroupSize: 25,
      promotionCount: 5,
      demotionCount: 0,
      protectedPlacementDays: 7,
      visualTier: 0,
      active: true,
    ),
    LeagueDefinition(
      id: 'league-iron',
      name: 'Iron',
      tier: LeagueTier.iron,
      minPlacementRating: 400,
      maxGroupSize: 25,
      promotionCount: 5,
      demotionCount: 5,
      protectedPlacementDays: 7,
      visualTier: 1,
      active: true,
    ),
  ];

  group('statusFor', () {
    test('a brand-new participant is a protected rookie', () {
      final status = RookiePlacementPolicy.statusFor(
        firstCompetitiveCompletionAt: start,
        competitiveCompletionCount: 1,
        now: start,
      );
      expect(status.isRookie, isTrue);
    });

    test('protection ends once the day threshold is reached, even with '
        'few completions', () {
      final status = RookiePlacementPolicy.statusFor(
        firstCompetitiveCompletionAt: start,
        competitiveCompletionCount: 1,
        now: start.add(
          Duration(days: CompetitionScoringConstants.rookieProtectionDays),
        ),
      );
      expect(status.isRookie, isFalse);
    });

    test('protection ends once the completion-count threshold is reached, '
        'even on day one', () {
      final status = RookiePlacementPolicy.statusFor(
        firstCompetitiveCompletionAt: start,
        competitiveCompletionCount:
            CompetitionScoringConstants.rookieProtectionCompletions,
        now: start,
      );
      expect(status.isRookie, isFalse);
    });

    test('account age alone never appears in the exit reason', () {
      final status = RookiePlacementPolicy.statusFor(
        firstCompetitiveCompletionAt: start,
        competitiveCompletionCount: 0,
        now: start,
      );
      expect(status.reason.toLowerCase(), isNot(contains('account age')));
    });
  });

  group('placeFor', () {
    test('no early scores places into the floor league', () {
      final result = RookiePlacementPolicy.placeFor(
        userId: 'u1',
        leagues: leagues,
        earlyScores: const [],
      );
      expect(result.assignedLeagueId, 'league-ember');
      expect(result.basedOnCompletionCount, 0);
    });

    test('strong early performance places above the floor league', () {
      final result = RookiePlacementPolicy.placeFor(
        userId: 'u1',
        leagues: leagues,
        earlyScores: const [500, 500, 500],
      );
      expect(result.assignedLeagueId, 'league-iron');
    });

    test('placement is derived only from performance, never lifetime XP or '
        'account age (there is no such parameter to pass)', () {
      // Structural guarantee: `placeFor` has no lifetime-XP or account-age
      // parameter at all, so it is impossible for either to influence it.
      expect(
        () => RookiePlacementPolicy.placeFor(
          userId: 'u1',
          leagues: leagues,
          earlyScores: const [100],
        ),
        returnsNormally,
      );
    });
  });
}
