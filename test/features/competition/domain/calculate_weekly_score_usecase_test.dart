import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/data/repositories/in_memory_competition_repository.dart';
import 'package:forge/features/competition/domain/entities/competition_week.dart';
import 'package:forge/features/competition/domain/enums/competition_week_status.dart';
import 'package:forge/features/competition/domain/policies/competition_scoring_constants.dart';
import 'package:forge/features/competition/domain/usecases/calculate_weekly_score_usecase.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';

import '../../../support/competition_test_helpers.dart';

void main() {
  final weekStart = DateTime.utc(2026, 8, 3);
  final week = CompetitionWeek(
    seasonId: 'season-1',
    weekNumber: 1,
    startsAt: weekStart,
    endsAt: weekStart.add(const Duration(days: 7)),
    status: CompetitionWeekStatus.active,
  );

  test(
    'a single valid completion contributes a positive capped score',
    () async {
      final repository = InMemoryCompetitionRepository();
      await repository.recordCompletion(
        testCompetitiveSummary(
          missionInstanceId: 'm1',
          completedAt: weekStart.add(const Duration(hours: 1)),
        ),
      );

      final result = await CalculateWeeklyScoreUseCase(repository)(
        userId: testCompetitionUserId,
        week: week,
      );

      expect(result.cappedScore, greaterThan(0));
      expect(result.completedMissionCount, 1);
    },
  );

  test(
    'recording the exact same missionInstanceId twice scores it only once',
    () async {
      final singleRepository = InMemoryCompetitionRepository();
      await singleRepository.recordCompletion(
        testCompetitiveSummary(
          missionInstanceId: 'm1',
          completedAt: weekStart.add(const Duration(hours: 1)),
        ),
      );
      final single = await CalculateWeeklyScoreUseCase(singleRepository)(
        userId: testCompetitionUserId,
        week: week,
      );

      final duplicatedRepository = InMemoryCompetitionRepository();
      await duplicatedRepository.recordCompletion(
        testCompetitiveSummary(
          missionInstanceId: 'm1',
          completedAt: weekStart.add(const Duration(hours: 1)),
        ),
      );
      await duplicatedRepository.recordCompletion(
        testCompetitiveSummary(
          missionInstanceId: 'm1',
          completedAt: weekStart.add(const Duration(hours: 2)),
        ),
      );
      final duplicated = await CalculateWeeklyScoreUseCase(
        duplicatedRepository,
      )(userId: testCompetitionUserId, week: week);

      expect(duplicated.cappedScore, single.cappedScore);
    },
  );

  test('completions outside the requested week are ignored', () async {
    final repository = InMemoryCompetitionRepository();
    await repository.recordCompletion(
      testCompetitiveSummary(
        missionInstanceId: 'before',
        completedAt: weekStart.subtract(const Duration(days: 1)),
      ),
    );

    final result = await CalculateWeeklyScoreUseCase(repository)(
      userId: testCompetitionUserId,
      week: week,
    );

    expect(result.completedMissionCount, 0);
    expect(result.cappedScore, 0);
  });

  test('the weekly score never exceeds the weekly cap even with many '
      'high-scoring completions', () async {
    final repository = InMemoryCompetitionRepository();
    for (var i = 0; i < 40; i++) {
      await repository.recordCompletion(
        testCompetitiveSummary(
          missionInstanceId: 'm$i',
          completedAt: weekStart.add(Duration(hours: i)),
          category: MissionCategory.values[i % MissionCategory.values.length],
        ),
      );
    }

    final result = await CalculateWeeklyScoreUseCase(repository)(
      userId: testCompetitionUserId,
      week: week,
    );

    expect(
      result.cappedScore,
      lessThanOrEqualTo(CompetitionScoringConstants.maxScorePerWeek),
    );
  });

  test(
    'the weekly score is saved as a local preview after calculation',
    () async {
      final repository = InMemoryCompetitionRepository();
      await repository.recordCompletion(
        testCompetitiveSummary(
          missionInstanceId: 'm1',
          completedAt: weekStart.add(const Duration(hours: 1)),
        ),
      );

      await CalculateWeeklyScoreUseCase(repository)(
        userId: testCompetitionUserId,
        week: week,
      );

      final saved = await repository.weeklyScoresForUser(
        testCompetitionUserId,
        'season-1',
      );
      expect(saved, hasLength(1));
      expect(saved.single.weekNumber, 1);
    },
  );
}
