import 'package:flutter/foundation.dart';

/// The full, explainable breakdown of one completion's competitive score —
/// mirrors `XpRewardEvaluation`'s philosophy of keeping every factor
/// separate rather than collapsing straight to a final number, so the UI,
/// tests, and a future backend re-validation can all see exactly how the
/// score was built.
@immutable
class CompetitiveScoreEvaluation {
  const CompetitiveScoreEvaluation({
    required this.missionInstanceId,
    required this.baseScore,
    required this.difficultyFactor,
    required this.qualityFactor,
    required this.diversityFactor,
    required this.consistencyFactor,
    required this.repetitionAdjustment,
    required this.recoveryAdjustment,
    required this.integrityAdjustment,
    required this.finalScorePreview,
    required this.reasons,
    required this.scoringVersion,
    this.provisionalOnly = true,
  });

  final String missionInstanceId;

  final double baseScore;
  final double difficultyFactor;
  final double qualityFactor;
  final double diversityFactor;

  /// Always `1.0` here — true weekly consistency bonuses are computed once
  /// per week by `CompetitionConsistencyPolicy` during aggregation, not
  /// per completion (there is no meaningful "consistency so far today").
  /// Kept as an explicit field anyway so every evaluation shows the same
  /// factor breakdown shape.
  final double consistencyFactor;

  /// Always `<= 0` — diminishing returns for repeating the same mission
  /// family recently.
  final double repetitionAdjustment;

  /// Always `<= 0` — normalizes (never boosts) recovery-mission
  /// contribution; see `RecoveryCompetitionPolicy`.
  final double recoveryAdjustment;

  /// Always `<= 0`; drives the score to exactly `0` for an invalid,
  /// duplicate, or excluded completion.
  final double integrityAdjustment;

  /// The clamped, capped result after every factor/adjustment above —
  /// never negative, never above `CompetitionCapPolicy.maxScorePerMission`.
  final double finalScorePreview;

  final List<String> reasons;

  /// Bumped whenever `ForgeCompetitiveScorePolicy`'s formula changes.
  final int scoringVersion;

  final bool provisionalOnly;
}
