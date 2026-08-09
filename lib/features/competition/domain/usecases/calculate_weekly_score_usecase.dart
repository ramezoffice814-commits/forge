import '../../../missions/domain/enums/mission_category.dart';
import '../entities/competition_week.dart';
import '../entities/weekly_competition_score.dart';
import '../enums/integrity_signal.dart';
import '../policies/competition_cap_policy.dart';
import '../policies/competition_consistency_policy.dart';
import '../policies/competition_integrity_policy.dart';
import '../policies/forge_competitive_score_policy.dart';
import '../repositories/competition_repository.dart';

String _utcDayKey(DateTime instant) {
  final utc = instant.toUtc();
  return '${utc.year}-${utc.month}-${utc.day}';
}

/// Folds a user's completions for one week into a single, capped,
/// explainable [WeeklyCompetitionScore]. This is the one place per-mission,
/// per-category-per-day, per-day, and per-week caps are all applied in
/// sequence — see `CompetitionCapPolicy`.
class CalculateWeeklyScoreUseCase {
  const CalculateWeeklyScoreUseCase(this._repository);

  final CompetitionRepository _repository;

  Future<WeeklyCompetitionScore> call({
    required String userId,
    required CompetitionWeek week,
  }) async {
    final allCompletions = await _repository.completionsForUser(userId);
    final weekCompletions =
        allCompletions.where((c) => week.contains(c.completedAt)).toList()
          ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    final seenMissionInstanceIds = <String>{};
    final categoryCountsThisWeek = <MissionCategory, int>{};
    final categoryDayTotals = <String, double>{};
    final dayTotals = <String, double>{};
    final dayCompletionCounts = <String, int>{};
    final activeDays = <String>{};
    final categoriesUsed = <MissionCategory>{};
    final integrityFlags = <IntegritySignal>{};

    var missionScoreSum = 0.0;
    DateTime? previousCompletionAt;

    for (final completion in weekCompletions) {
      final dayKey = _utcDayKey(completion.completedAt);
      final isDuplicate = !seenMissionInstanceIds.add(
        completion.missionInstanceId,
      );
      dayCompletionCounts[dayKey] = (dayCompletionCounts[dayKey] ?? 0) + 1;

      final integrityEvaluation = CompetitionIntegrityPolicy.evaluateCompletion(
        summary: completion,
        now: completion.completedAt,
        isDuplicate: isDuplicate,
        previousCompletionAt: previousCompletionAt,
        completionsTodayIncludingThis: dayCompletionCounts[dayKey]!,
      );
      previousCompletionAt = completion.completedAt;
      integrityFlags.addAll(integrityEvaluation.signals);

      final effectiveIntegrityState =
          integrityEvaluation.state.index > completion.eventIntegrityState.index
          ? integrityEvaluation.state
          : completion.eventIntegrityState;
      final effectiveSummary = completion.withEventIntegrityState(
        effectiveIntegrityState,
      );

      final priorInCategory = categoryCountsThisWeek[completion.category] ?? 0;
      categoryCountsThisWeek[completion.category] = priorInCategory + 1;
      categoriesUsed.add(completion.category);

      var score = isDuplicate
          ? 0.0
          : ForgeCompetitiveScorePolicy.evaluate(
              summary: effectiveSummary,
              priorCompletionsInCategoryThisWeek: priorInCategory,
            ).finalScorePreview;
      if (isDuplicate) integrityFlags.add(IntegritySignal.duplicateCompletion);

      final categoryDayKey = '${completion.category.name}-$dayKey';
      final priorCategoryDayTotal = categoryDayTotals[categoryDayKey] ?? 0;
      score = CompetitionCapPolicy.clampForCategoryDay(
        score: score,
        priorCategoryTotalToday: priorCategoryDayTotal,
      );
      categoryDayTotals[categoryDayKey] = priorCategoryDayTotal + score;

      final priorDayTotal = dayTotals[dayKey] ?? 0;
      score = CompetitionCapPolicy.clampForDay(
        score: score,
        priorDayTotal: priorDayTotal,
      );
      dayTotals[dayKey] = priorDayTotal + score;

      missionScoreSum += score;
      if (score > 0) activeDays.add(dayKey);
    }

    final consistencyBonus = CompetitionConsistencyPolicy.bonusFor(
      activeDays: activeDays.length,
      rawScore: missionScoreSum,
    );
    final rawScore = missionScoreSum + consistencyBonus;
    final cappedScore = CompetitionCapPolicy.clampForWeek(
      score: rawScore,
      priorWeekTotal: 0,
    );

    final result = WeeklyCompetitionScore(
      userId: userId,
      seasonId: week.seasonId,
      weekNumber: week.weekNumber,
      rawScore: rawScore,
      cappedScore: cappedScore,
      completedMissionCount: weekCompletions.length,
      activeDays: activeDays.length,
      categoriesUsed: categoriesUsed,
      integrityFlags: integrityFlags,
      scoreBreakdown: {
        'missions': missionScoreSum,
        'consistencyBonus': consistencyBonus,
      },
    );

    await _repository.saveLocalPreview(result);
    return result;
  }
}
