import 'package:flutter/foundation.dart';

/// The full, explainable breakdown of one mission's XP evaluation. Every
/// numeric factor is kept separate (rather than collapsing straight to
/// [finalXpPreview]) so the UI, tests, and a future backend re-validation
/// can all see exactly how the number was built — never a black box.
///
/// [provisionalOnly] is always `true` here; nothing in this module ever
/// constructs one with it `false` (see the trust-boundary notes on
/// `UserProgressionProfile`). A future backend independently recomputes and
/// confirms before any of this becomes real, competitive XP.
@immutable
class XpRewardEvaluation {
  const XpRewardEvaluation({
    required this.missionInstanceId,
    required this.baseXp,
    required this.difficultyMultiplier,
    required this.categoryMultiplier,
    required this.consistencyBonus,
    required this.recoveryBonus,
    required this.penaltyAdjustments,
    required this.finalXpPreview,
    required this.reasons,
    required this.evaluationVersion,
    this.provisionalOnly = true,
  });

  final String missionInstanceId;

  final int baseXp;
  final double difficultyMultiplier;
  final double categoryMultiplier;

  /// Additive XP for an active streak — capped, see
  /// `XpCalculationPolicy.maxStreakBonus`.
  final int consistencyBonus;

  /// Additive XP for a recovery-mode mission — deliberately flat and small
  /// (see spec: "reward effort but not competitive advantage").
  final int recoveryBonus;

  /// Always `<= 0` — diminishing returns for repeating the same mission
  /// recently, or other abuse-prevention adjustments. Negative, not a
  /// multiplier, so it's easy to explain in [reasons] as a flat deduction.
  final int penaltyAdjustments;

  /// The clamped, capped result after every factor above is applied — see
  /// `XpCalculationPolicy.maxXpPerMission`/`maxDailyXpPreview`.
  final int finalXpPreview;

  final List<String> reasons;

  /// Bumped whenever the formula itself changes, so a stored evaluation can
  /// always be traced back to the rules that produced it.
  final String evaluationVersion;

  final bool provisionalOnly;
}
