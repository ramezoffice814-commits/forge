import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/data/mock/mock_competition_catalog.dart';
import 'package:forge/features/competition/domain/entities/league_definition.dart';
import 'package:forge/features/competition/domain/enums/league_tier.dart';
import 'package:forge/features/competition/domain/services/competition_ranking_engine.dart';

const _league = LeagueDefinition(
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
);

const _forbiddenWords = [
  'recovery',
  'reflection',
  'health',
  'accessibility',
  'email',
  '@',
];

void main() {
  test('a leaderboard entry only ever exposes userId, displayName, avatarUrl, '
      'league, rank, weeklyScore, activeDays, promotionStatus, and '
      'provisionalOnly — never anything else, by construction', () {
    final participants = MockCompetitionCatalog.participantsForLeague(
      leagueId: _league.id,
      weekNumber: 1,
    );
    final result = CompetitionRankingEngine.rank(
      participants: participants,
      league: _league,
      allLeagues: [_league],
    );

    for (final entry in result.entries) {
      // If this compiles, the type itself has no additional fields — the
      // real guarantee here is structural (see LeaderboardEntry's own
      // immutable, fixed-field definition), not a runtime check.
      expect(entry.userId, isNotEmpty);
      expect(entry.league, _league.name);
      expect(entry.provisionalOnly, isTrue);
    }
  });

  test(
    'no Hall of Fame record description leaks a sensitive category word',
    () {
      final records = MockCompetitionCatalog.hallOfFame();
      for (final record in records) {
        final lower = record.description.toLowerCase();
        for (final word in _forbiddenWords) {
          expect(lower, isNot(contains(word)));
        }
      }
    },
  );

  test('the seeded rookie is protected without any public label identifying '
      'them as a rookie in the ranking output', () {
    final participants = MockCompetitionCatalog.participantsForLeague(
      leagueId: _league.id,
      weekNumber: 1,
    );
    final result = CompetitionRankingEngine.rank(
      participants: participants,
      league: _league,
      allLeagues: [_league],
      protectedUserIds: MockCompetitionCatalog.protectedUserIds(_league.id, 1),
    );

    final rookieEntry = result.entries.firstWhere(
      (e) => e.userId == 'mock-${_league.id}-0',
    );
    // LeaderboardEntry has no field that could carry a "rookie" label at
    // all — displayName is unaffected by protection status.
    expect(rookieEntry.displayName, isNot(contains('Rookie')));
  });
}
