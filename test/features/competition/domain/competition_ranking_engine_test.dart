import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/domain/entities/league_definition.dart';
import 'package:forge/features/competition/domain/entities/weekly_competition_score.dart';
import 'package:forge/features/competition/domain/enums/league_tier.dart';
import 'package:forge/features/competition/domain/services/competition_ranking_engine.dart';

const _iron = LeagueDefinition(
  id: 'league-iron',
  name: 'Iron',
  tier: LeagueTier.iron,
  minPlacementRating: 400,
  maxGroupSize: 25,
  promotionCount: 1,
  demotionCount: 1,
  protectedPlacementDays: 7,
  visualTier: 1,
  active: true,
);

const _ember = LeagueDefinition(
  id: 'league-ember',
  name: 'Ember',
  tier: LeagueTier.ember,
  minPlacementRating: 0,
  maxGroupSize: 25,
  promotionCount: 1,
  demotionCount: 0,
  protectedPlacementDays: 7,
  visualTier: 0,
  active: true,
);

const _mythic = LeagueDefinition(
  id: 'league-mythic',
  name: 'Mythic',
  tier: LeagueTier.mythic,
  minPlacementRating: 3600,
  maxGroupSize: 25,
  promotionCount: 0,
  demotionCount: 1,
  protectedPlacementDays: 7,
  visualTier: 5,
  active: true,
);

const _allLeagues = [_ember, _iron, _mythic];

CompetitionRankingParticipant _participant(
  String userId,
  double score, {
  int activeDaysOverride = 4,
  DateTime? attainedAt,
}) {
  return CompetitionRankingParticipant(
    userId: userId,
    displayName: userId,
    weeklyScore: WeeklyCompetitionScore(
      userId: userId,
      seasonId: 'season-1',
      weekNumber: 1,
      rawScore: score,
      cappedScore: score,
      completedMissionCount: 5,
      activeDays: activeDaysOverride,
      categoriesUsed: const {},
      integrityFlags: const {},
      scoreBreakdown: const {},
    ),
    averageDifficulty: 2,
    scoreAttainedAt: attainedAt ?? DateTime.utc(2026, 8, 5),
  );
}

void main() {
  test('higher score ranks first', () {
    final result = CompetitionRankingEngine.rank(
      participants: [_participant('low', 10), _participant('high', 90)],
      league: _iron,
      allLeagues: _allLeagues,
    );
    expect(result.entries.first.userId, 'high');
    expect(result.entries.first.rank, 1);
  });

  test('the same input always produces the same ranking (determinism)', () {
    final participants = [
      _participant('a', 30),
      _participant('b', 90),
      _participant('c', 60),
    ];
    final first = CompetitionRankingEngine.rank(
      participants: participants,
      league: _iron,
      allLeagues: _allLeagues,
    );
    final second = CompetitionRankingEngine.rank(
      participants: participants,
      league: _iron,
      allLeagues: _allLeagues,
    );
    expect(
      first.entries.map((e) => e.userId).toList(),
      second.entries.map((e) => e.userId).toList(),
    );
  });

  test('a newcomer with a strong week can outrank an established participant '
      'with a weaker week', () {
    final result = CompetitionRankingEngine.rank(
      participants: [
        _participant('veteran', 20),
        _participant('newcomer', 200),
      ],
      league: _iron,
      allLeagues: _allLeagues,
    );
    expect(result.entries.first.userId, 'newcomer');
  });

  test(
    'a tie is broken deterministically and recorded as a tie-break note',
    () {
      final result = CompetitionRankingEngine.rank(
        participants: [
          _participant('a', 50, activeDaysOverride: 3),
          _participant('b', 50, activeDaysOverride: 6),
        ],
        league: _iron,
        allLeagues: _allLeagues,
      );
      // More active days wins the tie.
      expect(result.entries.first.userId, 'b');
      expect(result.tieBreakNotes, contains('a'));
    },
  );

  test('promotion/demotion zone sets reflect the movement policy', () {
    final result = CompetitionRankingEngine.rank(
      participants: [
        _participant('top', 90),
        _participant('mid', 50),
        _participant('bottom', 10),
      ],
      league: _iron,
      allLeagues: _allLeagues,
    );
    expect(result.promotionZoneUserIds, {'top'});
    expect(result.demotionZoneUserIds, {'bottom'});
  });

  // `CompetitionRankingParticipant` has no XP field at all — the only
  // numeric score input is `WeeklyCompetitionScore.cappedScore`, which
  // `ForgeCompetitiveScorePolicy` never derives from XP. That structural
  // absence is what the "newcomer can outrank a veteran" test above
  // actually exercises: a participant's score is entirely independent of
  // how long they've been playing.
}
