import 'dart:math' as math;

import '../entities/competitive_completion_summary.dart';
import '../entities/competitive_score_evaluation.dart';
import '../enums/completion_validation_state.dart';
import '../enums/competition_integrity_state.dart';
import 'competition_cap_policy.dart';
import 'competition_diversity_policy.dart';
import 'competition_scoring_constants.dart';
import 'recovery_competition_policy.dart';

/// The single formula for one completion's competitive contribution —
/// deliberately never equal to XP (spec section 8's core rule). Every step
/// is kept as a named, explainable adjustment on [CompetitiveScoreEvaluation]
/// rather than collapsed into one opaque multiply, so a mismatch between
/// "what the user expects" and "what they got" is always traceable.
///
/// An invalid, unverified, or excluded completion scores exactly `0` —
/// never a reduced positive number — matching the fairness rule that
/// "invalid/unverified completions score zero" (spec section 9), not
/// "score less".
abstract final class ForgeCompetitiveScorePolicy {
  static CompetitiveScoreEvaluation evaluate({
    required CompetitiveCompletionSummary summary,
    required int priorCompletionsInCategoryThisWeek,
  }) {
    final reasons = <String>[];

    if (summary.validationState != CompletionValidationState.valid) {
      reasons.add('Completion is not yet validated — scores zero');
      return _zero(summary, reasons);
    }
    if (summary.eventIntegrityState == CompetitionIntegrityState.excluded) {
      reasons.add('Some activity is pending verification — scores zero');
      return _zero(summary, reasons);
    }

    final baseScore = CompetitionScoringConstants.baseCompletionScore;
    final difficultyFactor =
        CompetitionScoringConstants.difficultyFactors[summary
            .difficulty
            .name] ??
        1.0;
    final qualityFactor =
        CompetitionScoringConstants.qualityFactors[summary
            .completionQuality
            .name] ??
        1.0;
    final diversityFactor = CompetitionDiversityPolicy.factorFor(
      category: summary.category,
      priorCompletionsInCategoryThisWeek: priorCompletionsInCategoryThisWeek,
    );
    const consistencyFactor = 1.0;

    reasons.add(
      'Base ${baseScore.toStringAsFixed(1)} × difficulty '
      '${difficultyFactor.toStringAsFixed(2)} × quality '
      '${qualityFactor.toStringAsFixed(2)} × diversity '
      '${diversityFactor.toStringAsFixed(2)}',
    );

    final product =
        baseScore *
        difficultyFactor *
        qualityFactor *
        diversityFactor *
        consistencyFactor;

    final repeated = summary.repeatedMissionCount.clamp(0, 1000);
    final retainedFraction = math.pow(
      CompetitionScoringConstants.repetitionDecayFactor,
      repeated,
    );
    final repetitionAdjustment = repeated == 0
        ? 0.0
        : -(product * (1 - retainedFraction));
    if (repeated > 0) {
      reasons.add('Repeated $repeated time(s) recently — diminishing returns');
    }
    final afterRepetition = product + repetitionAdjustment;

    final recoveryAdjustment = RecoveryCompetitionPolicy.adjustmentFor(
      recoveryMission: summary.recoveryMission,
      rawScore: afterRepetition,
    );
    if (recoveryAdjustment < 0) {
      reasons.add(RecoveryCompetitionPolicy.explain(recoveryMission: true));
    }
    final afterRecovery = afterRepetition + recoveryAdjustment;

    double integrityAdjustment = 0.0;
    if (summary.eventIntegrityState == CompetitionIntegrityState.warning) {
      integrityAdjustment = -(afterRecovery * 0.5);
      reasons.add('Some activity is pending verification — reduced value');
    }
    final afterIntegrity = afterRecovery + integrityAdjustment;

    final finalScore = CompetitionCapPolicy.clampMissionScore(afterIntegrity);
    if (afterIntegrity > finalScore) {
      reasons.add('Capped at per-mission maximum');
    }

    return CompetitiveScoreEvaluation(
      missionInstanceId: summary.missionInstanceId,
      baseScore: baseScore,
      difficultyFactor: difficultyFactor,
      qualityFactor: qualityFactor,
      diversityFactor: diversityFactor,
      consistencyFactor: consistencyFactor,
      repetitionAdjustment: repetitionAdjustment,
      recoveryAdjustment: recoveryAdjustment,
      integrityAdjustment: integrityAdjustment,
      finalScorePreview: finalScore,
      reasons: List.unmodifiable(reasons),
      scoringVersion: CompetitionScoringConstants.scoringVersion,
    );
  }

  static CompetitiveScoreEvaluation _zero(
    CompetitiveCompletionSummary summary,
    List<String> reasons,
  ) {
    return CompetitiveScoreEvaluation(
      missionInstanceId: summary.missionInstanceId,
      baseScore: 0,
      difficultyFactor: 0,
      qualityFactor: 0,
      diversityFactor: 0,
      consistencyFactor: 0,
      repetitionAdjustment: 0,
      recoveryAdjustment: 0,
      integrityAdjustment: 0,
      finalScorePreview: 0,
      reasons: List.unmodifiable(reasons),
      scoringVersion: CompetitionScoringConstants.scoringVersion,
    );
  }
}
