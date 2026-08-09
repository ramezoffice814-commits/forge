import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/domain/entities/league_definition.dart';
import 'package:forge/features/competition/domain/enums/league_tier.dart';
import 'package:forge/features/competition/domain/policies/mock_league_grouping_policy.dart';

const _league = LeagueDefinition(
  id: 'league-iron',
  name: 'Iron',
  tier: LeagueTier.iron,
  minPlacementRating: 400,
  maxGroupSize: 3,
  promotionCount: 1,
  demotionCount: 1,
  protectedPlacementDays: 7,
  visualTier: 1,
  active: true,
);

List<CompetitionGroupingContext> _participants(int count) {
  return List.generate(
    count,
    (i) => CompetitionGroupingContext(
      userId: 'u$i',
      isRookie: i == 0,
      recentScoreBand: i % 2,
      timezoneBucket: i.isEven ? 'UTC+0' : 'UTC+8',
    ),
  );
}

void main() {
  final createdAt = DateTime.utc(2026, 8, 10);

  test('no group ever exceeds the league max group size', () {
    final groups = MockLeagueGroupingPolicy.buildGroups(
      seasonId: 'season-1',
      weekNumber: 1,
      league: _league,
      participants: _participants(10),
      createdAt: createdAt,
    );
    for (final group in groups) {
      expect(
        group.participantIds.length,
        lessThanOrEqualTo(_league.maxGroupSize),
      );
    }
  });

  test('every participant appears in exactly one group', () {
    final participants = _participants(10);
    final groups = MockLeagueGroupingPolicy.buildGroups(
      seasonId: 'season-1',
      weekNumber: 1,
      league: _league,
      participants: participants,
      createdAt: createdAt,
    );
    final allAssigned = groups.expand((g) => g.participantIds).toList();
    expect(allAssigned.toSet(), participants.map((p) => p.userId).toSet());
    expect(allAssigned.length, participants.length); // no duplicates
  });

  test('the same input always produces the same groups (determinism)', () {
    final participants = _participants(10);
    final first = MockLeagueGroupingPolicy.buildGroups(
      seasonId: 'season-1',
      weekNumber: 1,
      league: _league,
      participants: participants,
      createdAt: createdAt,
    );
    final second = MockLeagueGroupingPolicy.buildGroups(
      seasonId: 'season-1',
      weekNumber: 1,
      league: _league,
      participants: participants,
      createdAt: createdAt,
    );
    expect(
      first.map((g) => g.participantIds).toList(),
      second.map((g) => g.participantIds).toList(),
    );
  });

  test('an empty participant list produces no groups', () {
    final groups = MockLeagueGroupingPolicy.buildGroups(
      seasonId: 'season-1',
      weekNumber: 1,
      league: _league,
      participants: const [],
      createdAt: createdAt,
    );
    expect(groups, isEmpty);
  });
}
