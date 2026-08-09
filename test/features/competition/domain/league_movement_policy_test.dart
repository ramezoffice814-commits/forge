import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/domain/entities/leaderboard_entry.dart';
import 'package:forge/features/competition/domain/entities/league_definition.dart';
import 'package:forge/features/competition/domain/enums/league_tier.dart';
import 'package:forge/features/competition/domain/enums/promotion_status.dart';
import 'package:forge/features/competition/domain/policies/league_movement_policy.dart';

const _ember = LeagueDefinition(
  id: 'league-ember',
  name: 'Ember',
  tier: LeagueTier.ember,
  minPlacementRating: 0,
  maxGroupSize: 25,
  promotionCount: 2,
  demotionCount: 0,
  protectedPlacementDays: 7,
  visualTier: 0,
  active: true,
);

const _iron = LeagueDefinition(
  id: 'league-iron',
  name: 'Iron',
  tier: LeagueTier.iron,
  minPlacementRating: 400,
  maxGroupSize: 25,
  promotionCount: 2,
  demotionCount: 2,
  protectedPlacementDays: 7,
  visualTier: 1,
  active: true,
);

const _mythic = LeagueDefinition(
  id: 'league-mythic',
  name: 'Mythic',
  tier: LeagueTier.mythic,
  minPlacementRating: 3600,
  maxGroupSize: 25,
  promotionCount: 0,
  demotionCount: 2,
  protectedPlacementDays: 7,
  visualTier: 5,
  active: true,
);

const _allLeagues = [_ember, _iron, _mythic];

List<LeaderboardEntry> _entriesFor(int count) {
  return List.generate(
    count,
    (i) => LeaderboardEntry(
      userId: 'u$i',
      displayName: 'User $i',
      league: _iron.name,
      rank: i + 1,
      weeklyScore: (count - i).toDouble(),
      activeDays: 5,
      promotionStatus: PromotionStatus.safeZone,
    ),
  );
}

void main() {
  test('top ranks land in the promotion zone, bottom ranks in the demotion '
      'zone, middle ranks stay safe', () {
    final entries = _entriesFor(6);
    final movements = LeagueMovementPolicy.evaluate(
      rankedEntries: entries,
      league: _iron,
      allLeagues: _allLeagues,
      protectedUserIds: const {},
    );

    expect(movements[0].zone, PromotionStatus.promotionZone);
    expect(movements[1].zone, PromotionStatus.promotionZone);
    expect(movements[2].zone, PromotionStatus.safeZone);
    expect(movements[3].zone, PromotionStatus.safeZone);
    expect(movements[4].zone, PromotionStatus.demotionZone);
    expect(movements[5].zone, PromotionStatus.demotionZone);
  });

  test('the floor league never demotes anyone, regardless of rank', () {
    final entries = _entriesFor(6);
    final movements = LeagueMovementPolicy.evaluate(
      rankedEntries: entries,
      league: _ember,
      allLeagues: _allLeagues,
      protectedUserIds: const {},
    );
    for (final movement in movements) {
      expect(movement.zone, isNot(PromotionStatus.demotionZone));
    }
  });

  test('the ceiling league never promotes anyone, regardless of rank', () {
    final entries = _entriesFor(6);
    final movements = LeagueMovementPolicy.evaluate(
      rankedEntries: entries,
      league: _mythic,
      allLeagues: _allLeagues,
      protectedUserIds: const {},
    );
    for (final movement in movements) {
      expect(movement.zone, isNot(PromotionStatus.promotionZone));
    }
  });

  test('a protected user in the demotion zone is suppressed to safe, not '
      'demoted', () {
    final entries = _entriesFor(6);
    final movements = LeagueMovementPolicy.evaluate(
      rankedEntries: entries,
      league: _iron,
      allLeagues: _allLeagues,
      protectedUserIds: {'u5'},
    );
    final lastPlace = movements.firstWhere((m) => m.userId == 'u5');
    expect(lastPlace.zone, PromotionStatus.safeZone);
    expect(lastPlace.protected, isTrue);
  });

  group('compareForRanking tie-break order', () {
    test('higher score always wins first', () {
      final result = LeagueMovementPolicy.compareForRanking(
        scoreA: 100,
        scoreB: 50,
        activeDaysA: 1,
        activeDaysB: 7,
        avgDifficultyA: 0,
        avgDifficultyB: 4,
        attainedAtA: DateTime.utc(2026, 1, 2),
        attainedAtB: DateTime.utc(2026, 1, 1),
        userIdA: 'z',
        userIdB: 'a',
      );
      expect(result, lessThan(0)); // a sorts before b
    });

    test('tied score falls back to more active days', () {
      final result = LeagueMovementPolicy.compareForRanking(
        scoreA: 100,
        scoreB: 100,
        activeDaysA: 7,
        activeDaysB: 3,
        avgDifficultyA: 0,
        avgDifficultyB: 4,
        attainedAtA: DateTime.utc(2026, 1, 2),
        attainedAtB: DateTime.utc(2026, 1, 1),
        userIdA: 'z',
        userIdB: 'a',
      );
      expect(result, lessThan(0));
    });

    test('tied score and active days falls back to average difficulty', () {
      final result = LeagueMovementPolicy.compareForRanking(
        scoreA: 100,
        scoreB: 100,
        activeDaysA: 5,
        activeDaysB: 5,
        avgDifficultyA: 3,
        avgDifficultyB: 1,
        attainedAtA: DateTime.utc(2026, 1, 2),
        attainedAtB: DateTime.utc(2026, 1, 1),
        userIdA: 'z',
        userIdB: 'a',
      );
      expect(result, lessThan(0));
    });

    test('tied score/days/difficulty falls back to earlier attainment', () {
      final result = LeagueMovementPolicy.compareForRanking(
        scoreA: 100,
        scoreB: 100,
        activeDaysA: 5,
        activeDaysB: 5,
        avgDifficultyA: 2,
        avgDifficultyB: 2,
        attainedAtA: DateTime.utc(2026, 1, 1),
        attainedAtB: DateTime.utc(2026, 1, 2),
        userIdA: 'z',
        userIdB: 'a',
      );
      expect(result, lessThan(0));
    });

    test('a total tie falls back to a deterministic userId comparison', () {
      final result = LeagueMovementPolicy.compareForRanking(
        scoreA: 100,
        scoreB: 100,
        activeDaysA: 5,
        activeDaysB: 5,
        avgDifficultyA: 2,
        avgDifficultyB: 2,
        attainedAtA: DateTime.utc(2026, 1, 1),
        attainedAtB: DateTime.utc(2026, 1, 1),
        userIdA: 'a',
        userIdB: 'z',
      );
      expect(result, lessThan(0));
    });
  });
}
