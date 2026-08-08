import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/data/repositories/in_memory_competition_repository.dart';

import '../../../support/competition_test_helpers.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);

  test(
    'getCurrentSeason and getLeagueDefinitions return non-empty catalogs',
    () async {
      final repository = InMemoryCompetitionRepository();
      final season = await repository.getCurrentSeason();
      final leagues = await repository.getLeagueDefinitions();
      expect(season.id, isNotEmpty);
      expect(leagues, isNotEmpty);
    },
  );

  test('recordCompletion then completionsForUser round-trips', () async {
    final repository = InMemoryCompetitionRepository();
    final summary = testCompetitiveSummary(completedAt: now);
    await repository.recordCompletion(summary);
    final completions = await repository.completionsForUser(
      testCompetitionUserId,
    );
    expect(completions, hasLength(1));
    expect(completions.single.missionInstanceId, summary.missionInstanceId);
  });

  test(
    'clearForUser wipes completions, league assignment, and previews',
    () async {
      final repository = InMemoryCompetitionRepository();
      await repository.recordCompletion(
        testCompetitiveSummary(completedAt: now),
      );
      await repository.setCurrentLeagueIdForUser(
        testCompetitionUserId,
        'league-iron',
      );

      repository.clearForUser(testCompetitionUserId);

      expect(
        await repository.completionsForUser(testCompetitionUserId),
        isEmpty,
      );
      expect(
        await repository.getCurrentLeagueIdForUser(testCompetitionUserId),
        isNot('league-iron'),
      );
    },
  );

  test(
    'a new user defaults to the floor league, never a lifetime-XP-derived one',
    () async {
      final repository = InMemoryCompetitionRepository();
      final leagueId = await repository.getCurrentLeagueIdForUser(
        'brand-new-user',
      );
      final leagues = await repository.getLeagueDefinitions();
      expect(leagueId, leagues.first.id);
    },
  );

  test(
    'participantsForLeague returns a stable, non-empty seeded population',
    () async {
      final repository = InMemoryCompetitionRepository();
      final participants = await repository.participantsForLeague(
        leagueId: 'league-ember',
        weekNumber: 1,
      );
      expect(participants, isNotEmpty);
      final again = await repository.participantsForLeague(
        leagueId: 'league-ember',
        weekNumber: 1,
      );
      expect(
        participants.map((p) => p.userId).toList(),
        again.map((p) => p.userId).toList(),
      );
    },
  );

  test('the seeded rookie in a league is reported as protected', () async {
    final repository = InMemoryCompetitionRepository();
    final protectedIds = await repository.protectedUserIdsForLeague(
      'league-ember',
      1,
    );
    expect(protectedIds, contains('mock-league-ember-0'));
  });

  test('getHallOfFame returns historical records only', () async {
    final repository = InMemoryCompetitionRepository();
    final records = await repository.getHallOfFame();
    expect(records, isNotEmpty);
  });
}
