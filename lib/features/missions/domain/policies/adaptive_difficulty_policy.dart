import '../entities/behavioral_history.dart';
import '../entities/user_discipline_profile.dart';
import '../enums/data_confidence.dart';
import '../enums/mission_category.dart';
import '../enums/mission_difficulty_level.dart';

class DifficultyResolution {
  const DifficultyResolution({
    required this.previousDifficulty,
    required this.resolvedDifficulty,
    required this.reasonCodes,
    required this.explanation,
    required this.confidence,
  });

  final MissionDifficultyLevel previousDifficulty;
  final MissionDifficultyLevel resolvedDifficulty;
  final List<String> reasonCodes;
  final List<String> explanation;
  final double confidence;
}

/// Resolves the target difficulty *for a category* — never mission-by-
/// mission — from category-scoped performance so a miss in one category
/// never drags down an unrelated one. Every rule here moves at most one
/// level per evaluation; see `MissionDifficultyLevelOrdinal`.
abstract final class AdaptiveDifficultyPolicy {
  static const _stabilizationThreshold = 2;

  static DifficultyResolution resolve({
    required MissionCategory category,
    required UserDisciplineProfile profile,
    required BehavioralHistory history,
    required bool recoveryActive,
  }) {
    final performance = history.performanceFor(category);
    final previous =
        performance.lastDifficulty ??
        profile.preferredDifficulty ??
        MissionDifficultyLevel.easy;

    final reasons = <String>[];
    final explanation = <String>[];
    var resolved = previous;

    if (recoveryActive) {
      if (previous.index > MissionDifficultyLevel.easy.index) {
        resolved = MissionDifficultyLevel.easy;
        reasons.add('recoveryCap');
        explanation.add('Capped at easy while recovery mode is active.');
      } else {
        explanation.add('Already at or below the recovery cap.');
      }
    } else if (history.recentDifficultyChangeCount >= _stabilizationThreshold) {
      // Avoid oscillation: hold steady for a stabilization period right
      // after back-to-back adjustments, regardless of what the raw
      // performance numbers say this round.
      reasons.add('stabilizing');
      explanation.add('Holding steady after a recent adjustment.');
    } else {
      final hasStableSuccessRun =
          performance.consecutiveComparableSuccesses >= 3;
      final effortManageable = (performance.averageEffort ?? 3) <= 3.5;
      final canIncrease =
          previous.index < MissionDifficultyLevel.advanced.index;

      final hasRepeatedMisses = performance.consecutiveComparableMisses >= 2;
      final effortExcessive = (performance.averageEffort ?? 0) >= 4.5;
      final canDecrease =
          previous.index > MissionDifficultyLevel.restorative.index;

      if (hasStableSuccessRun && effortManageable && canIncrease) {
        resolved = previous.oneLevelUp;
        reasons.add('stableSuccessIncrease');
        explanation.add(
          'Increased after ${performance.consecutiveComparableSuccesses} '
          'consecutive comparable successes.',
        );
      } else if ((hasRepeatedMisses || effortExcessive) && canDecrease) {
        resolved = previous.oneLevelDown;
        reasons.add(
          hasRepeatedMisses ? 'repeatedMissesDecrease' : 'highEffortDecrease',
        );
        explanation.add(
          hasRepeatedMisses
              ? 'Difficulty was reduced after repeated missed missions.'
              : 'Difficulty was reduced — recent missions felt too effortful.',
        );
      } else {
        explanation.add('Kept at the current level.');
      }
    }

    if (profile.manualIntensityCap != null &&
        resolved.index > profile.manualIntensityCap!.index) {
      resolved = profile.manualIntensityCap!;
      reasons.add('manualCap');
      explanation.add('Capped by your manual intensity setting.');
    }

    final confidence = performance.totalAttempts == 0
        ? 0.3
        : switch (history.dataConfidence) {
            DataConfidence.low => 0.4,
            DataConfidence.medium => 0.65,
            DataConfidence.high => 0.9,
          };

    return DifficultyResolution(
      previousDifficulty: previous,
      resolvedDifficulty: resolved,
      reasonCodes: reasons,
      explanation: explanation,
      confidence: confidence.clamp(0, 1).toDouble(),
    );
  }
}
