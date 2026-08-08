import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/domain/policies/competition_cap_policy.dart';
import 'package:forge/features/competition/domain/policies/competition_scoring_constants.dart';

void main() {
  test(
    'clampMissionScore never exceeds maxScorePerMission and never goes negative',
    () {
      expect(
        CompetitionCapPolicy.clampMissionScore(9999),
        CompetitionScoringConstants.maxScorePerMission,
      );
      expect(CompetitionCapPolicy.clampMissionScore(-5), 0);
      expect(CompetitionCapPolicy.clampMissionScore(3), 3);
    },
  );

  test('clampForCategoryDay only allows what remains under the cap', () {
    final remaining = CompetitionCapPolicy.clampForCategoryDay(
      score: 20,
      priorCategoryTotalToday:
          CompetitionScoringConstants.maxScorePerCategoryPerDay - 5,
    );
    expect(remaining, 5);
  });

  test('clampForCategoryDay returns zero once the cap is already reached', () {
    final remaining = CompetitionCapPolicy.clampForCategoryDay(
      score: 20,
      priorCategoryTotalToday:
          CompetitionScoringConstants.maxScorePerCategoryPerDay,
    );
    expect(remaining, 0);
  });

  test(
    'clampForDay and clampForWeek behave the same way at their own caps',
    () {
      expect(
        CompetitionCapPolicy.clampForDay(
          score: 100,
          priorDayTotal: CompetitionScoringConstants.maxScorePerDay,
        ),
        0,
      );
      expect(
        CompetitionCapPolicy.clampForWeek(
          score: 100,
          priorWeekTotal: CompetitionScoringConstants.maxScorePerWeek,
        ),
        0,
      );
    },
  );

  test(
    'every clamp method never returns a negative value for negative input',
    () {
      expect(
        CompetitionCapPolicy.clampForCategoryDay(
          score: -10,
          priorCategoryTotalToday: 0,
        ),
        0,
      );
      expect(CompetitionCapPolicy.clampForDay(score: -10, priorDayTotal: 0), 0);
      expect(
        CompetitionCapPolicy.clampForWeek(score: -10, priorWeekTotal: 0),
        0,
      );
    },
  );
}
