import '../entities/mission_definition.dart';

class TimeBudgetResolution {
  const TimeBudgetResolution({
    required this.fits,
    required this.resolvedMinutes,
  });

  final bool fits;
  final int resolvedMinutes;
}

/// Fits a mission's duration into the user's stated availability —
/// reserving a small setup/wind-down margin, never scaling below the
/// mission's own declared minimum, and never scaling above its maximum.
abstract final class TimeBudgetPolicy {
  static const setupMarginMinutes = 2;

  static TimeBudgetResolution resolve({
    required MissionDefinition mission,
    required int availableMinutesToday,
    int? requestedDuration,
  }) {
    final budget = (availableMinutesToday - setupMarginMinutes).clamp(
      0,
      availableMinutesToday < 0 ? 0 : availableMinutesToday,
    );

    if (mission.minimumMinutes > budget) {
      return TimeBudgetResolution(
        fits: false,
        resolvedMinutes: mission.minimumMinutes,
      );
    }

    final desired = (requestedDuration ?? mission.estimatedMinutes).clamp(
      mission.minimumMinutes,
      mission.maximumMinutes,
    );
    final resolved = desired > budget ? budget : desired;

    return TimeBudgetResolution(fits: true, resolvedMinutes: resolved);
  }

  /// 0–1: rewards landing close to the user's preferred duration and
  /// mildly penalizes consuming almost the entire available window when a
  /// shorter option would have done the job.
  static double timeFitScore({
    required int resolvedMinutes,
    required int availableMinutesToday,
    required int preferredDuration,
  }) {
    final reference = preferredDuration <= 0
        ? resolvedMinutes
        : preferredDuration;
    final distance = (resolvedMinutes - reference).abs();
    final closeness = reference == 0
        ? 1.0
        : (1 - (distance / reference)).clamp(0, 1).toDouble();

    final usageRatio = availableMinutesToday <= 0
        ? 0.0
        : resolvedMinutes / availableMinutesToday;
    final windowPenalty = usageRatio > 0.9 ? 0.3 : 0.0;

    return (closeness * 0.7 + (1 - windowPenalty) * 0.3).clamp(0, 1).toDouble();
  }
}
