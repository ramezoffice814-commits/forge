import '../entities/competition_integrity_evaluation.dart';
import '../entities/competitive_completion_summary.dart';
import '../enums/completion_validation_state.dart';
import '../enums/competition_integrity_state.dart';
import '../enums/integrity_signal.dart';
import '../enums/reward_authority_state.dart';
import 'competition_scoring_constants.dart';

/// Anti-cheat foundation (spec section 33). Never accusatory: the output
/// is a state (`clean`/`warning`/`excluded`) plus a set of internal-only
/// signals — any UI built on this must use neutral copy like "some
/// activity is pending verification," never name the specific signal.
///
/// [historicalAverageProvisionalXp] deliberately compares against
/// provisional XP, not the competitive score itself, to avoid a circular
/// dependency (the score is computed *from* this evaluation's result).
abstract final class CompetitionIntegrityPolicy {
  static CompetitionIntegrityEvaluation evaluateCompletion({
    required CompetitiveCompletionSummary summary,
    required DateTime now,
    required bool isDuplicate,
    DateTime? previousCompletionAt,
    required int completionsTodayIncludingThis,
    double? historicalAverageProvisionalXp,
  }) {
    final signals = <IntegritySignal>{};

    if (isDuplicate) signals.add(IntegritySignal.duplicateCompletion);

    if (previousCompletionAt != null) {
      final gapSeconds = summary.completedAt
          .difference(previousCompletionAt)
          .inSeconds
          .abs();
      if (gapSeconds <
          CompetitionScoringConstants.impossibleSequenceMinSeconds) {
        signals.add(IntegritySignal.impossibleSequence);
      }
    }

    if (completionsTodayIncludingThis >
        CompetitionScoringConstants.excessiveDailyVolumeThreshold) {
      signals.add(IntegritySignal.excessiveVolume);
    }

    if (summary.repeatedMissionCount >=
        CompetitionScoringConstants.repeatedFarmingThreshold) {
      signals.add(IntegritySignal.repeatedFarming);
    }

    if (historicalAverageProvisionalXp != null &&
        historicalAverageProvisionalXp > 0 &&
        summary.provisionalXp > historicalAverageProvisionalXp * 4) {
      signals.add(IntegritySignal.abnormalScoreJump);
    }

    if (summary.completedAt.isAfter(now.add(const Duration(minutes: 5)))) {
      signals.add(IntegritySignal.timestampAnomaly);
    }

    if (summary.validationState != CompletionValidationState.valid) {
      signals.add(IntegritySignal.invalidValidationState);
    }

    if (summary.rewardAuthorityState == RewardAuthorityState.localPreviewOnly) {
      signals.add(IntegritySignal.localOnlyUnconfirmed);
    }

    const excludingSignals = {
      IntegritySignal.duplicateCompletion,
      IntegritySignal.invalidValidationState,
      IntegritySignal.timestampAnomaly,
    };
    const warningSignals = {
      IntegritySignal.impossibleSequence,
      IntegritySignal.excessiveVolume,
      IntegritySignal.repeatedFarming,
      IntegritySignal.abnormalScoreJump,
    };

    final state = signals.any(excludingSignals.contains)
        ? CompetitionIntegrityState.excluded
        : signals.any(warningSignals.contains)
        ? CompetitionIntegrityState.warning
        : CompetitionIntegrityState.clean;

    return CompetitionIntegrityEvaluation(
      subjectId: summary.missionInstanceId,
      signals: signals,
      state: state,
      evaluatedAt: now,
    );
  }
}
