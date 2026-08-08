import 'competition_scoring_constants.dart';

/// "No advantage, no humiliation" (spec section 13): a recovery mission
/// still earns a meaningful, non-zero competitive contribution, but it can
/// never be farmed as an easy substitute for normal difficulty, and it is
/// never driven to zero or penalized beyond a normal cap.
abstract final class RecoveryCompetitionPolicy {
  /// [rawScore] is the score computed as if this were a normal mission
  /// (after difficulty/quality/diversity factors, before recovery
  /// normalization). Returns the (always `<= 0`) adjustment to apply.
  static double adjustmentFor({
    required bool recoveryMission,
    required double rawScore,
  }) {
    if (!recoveryMission) return 0.0;

    final cap = rawScore * CompetitionScoringConstants.recoveryScoreCapFraction;
    final overage = rawScore - cap;
    return overage > 0 ? -overage : 0.0;
  }

  static String explain({required bool recoveryMission}) {
    return recoveryMission
        ? 'Recovery mission — contribution normalized, not penalized'
        : 'Not a recovery mission';
  }
}
