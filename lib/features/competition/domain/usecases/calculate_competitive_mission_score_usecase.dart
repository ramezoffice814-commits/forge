import '../../../missions/domain/enums/mission_category.dart';
import '../entities/competitive_completion_summary.dart';
import '../entities/competitive_score_evaluation.dart';
import '../policies/forge_competitive_score_policy.dart';
import '../repositories/competition_repository.dart';

/// Scores exactly one completion — never all of a week's completions,
/// which is `CalculateWeeklyScoreUseCase`'s job. Kept separate so a single
/// completion's score can be previewed (e.g. right after a mission
/// finishes) without recomputing the whole week.
class CalculateCompetitiveMissionScoreUseCase {
  const CalculateCompetitiveMissionScoreUseCase(this._repository);

  final CompetitionRepository _repository;

  Future<CompetitiveScoreEvaluation> call(
    CompetitiveCompletionSummary summary, {
    required DateTime weekStartsAt,
  }) async {
    final priorCompletions = await _repository.completionsForUser(
      summary.userId,
    );
    final priorInCategoryThisWeek = priorCompletions.where((completion) {
      return completion.category == summary.category &&
          !completion.completedAt.isBefore(weekStartsAt) &&
          completion.completedAt.isBefore(summary.completedAt);
    }).length;

    final evaluation = ForgeCompetitiveScorePolicy.evaluate(
      summary: summary,
      priorCompletionsInCategoryThisWeek: priorInCategoryThisWeek,
    );

    await _repository.recordCompletion(summary);
    return evaluation;
  }
}

/// Exposed for callers (e.g. tests, or a future "how many times have I
/// done this category this week" widget) that want the raw count without
/// scoring — avoids duplicating the same filter elsewhere.
int priorCompletionsInCategory({
  required List<CompetitiveCompletionSummary> completions,
  required MissionCategory category,
  required DateTime weekStartsAt,
  required DateTime before,
}) {
  return completions.where((completion) {
    return completion.category == category &&
        !completion.completedAt.isBefore(weekStartsAt) &&
        completion.completedAt.isBefore(before);
  }).length;
}
