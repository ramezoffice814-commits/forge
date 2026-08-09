import 'competition_scoring_constants.dart';

/// Deterministic, config-driven caps — every clamp in the scoring pipeline
/// goes through here so no cap value is ever duplicated or hand-rolled
/// elsewhere (spec section 10). Every method is a pure clamp: never
/// negative, never above its cap.
abstract final class CompetitionCapPolicy {
  static double clampMissionScore(double score) {
    return score.clamp(0.0, CompetitionScoringConstants.maxScorePerMission);
  }

  /// [priorCategoryTotalToday] is the running total *before* adding
  /// [score]; returns the portion of [score] that actually counts.
  static double clampForCategoryDay({
    required double score,
    required double priorCategoryTotalToday,
  }) {
    final remaining =
        CompetitionScoringConstants.maxScorePerCategoryPerDay -
        priorCategoryTotalToday;
    if (remaining <= 0) return 0.0;
    return score.clamp(0.0, remaining);
  }

  static double clampForDay({
    required double score,
    required double priorDayTotal,
  }) {
    final remaining =
        CompetitionScoringConstants.maxScorePerDay - priorDayTotal;
    if (remaining <= 0) return 0.0;
    return score.clamp(0.0, remaining);
  }

  static double clampForWeek({
    required double score,
    required double priorWeekTotal,
  }) {
    final remaining =
        CompetitionScoringConstants.maxScorePerWeek - priorWeekTotal;
    if (remaining <= 0) return 0.0;
    return score.clamp(0.0, remaining);
  }
}
