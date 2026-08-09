import 'competition_scoring_constants.dart';

/// Rewards stable participation across a week without ever becoming an
/// infinite streak multiplier or a permanent historical advantage — see
/// spec section 12. Computed once per week from that week's active-day
/// count alone; a bad week never carries a penalty into the next one, and
/// missing a single day out of seven barely moves the bonus.
abstract final class CompetitionConsistencyPolicy {
  /// [activeDays] is 0..7. [rawScore] is the week's score *before* this
  /// bonus, so the bonus can be expressed as a small fraction of it.
  static double bonusFor({required int activeDays, required double rawScore}) {
    if (rawScore <= 0 || activeDays <= 1) return 0.0;

    // Linear ramp from day 2 (bonus starts to matter) to day 7 (full cap),
    // so one active day never spikes the bonus and losing one day out of
    // seven only trims it slightly.
    final ramp = ((activeDays - 1) / 6.0).clamp(0.0, 1.0);
    return rawScore *
        CompetitionScoringConstants.maxConsistencyBonusFraction *
        ramp;
  }

  static String explain({required int activeDays}) {
    if (activeDays <= 1) return 'Consistency bonus needs more active days';
    return 'Consistency bonus for $activeDays active days this week';
  }
}
