import '../../../missions/domain/enums/mission_difficulty_level.dart';
import '../entities/category_progress.dart';
import '../entities/completed_mission_summary.dart';
import '../entities/mission_history_snapshot.dart';
import '../entities/xp_reward_evaluation.dart';

/// Pure, deterministic, and fully explainable — the only place a mission's
/// XP preview is computed. No randomness, no hidden bonuses: every factor
/// below ends up in [XpRewardEvaluation.reasons].
///
/// [snapshot] must reflect history *before* [summary]'s own completion
/// (never including it) — that's what keeps the streak/category-tier/
/// diminishing-returns factors from referencing the very thing they're
/// scoring. See `EvaluateMissionRewardUseCase` for where that boundary is
/// enforced.
abstract final class XpCalculationPolicy {
  static const evaluationVersion = '1.0.0';

  /// Hard ceiling on any single mission's preview — no combination of
  /// bonuses can exceed this. A future backend enforces its own (possibly
  /// different) ceiling independently; this one only protects the local
  /// preview from looking absurd.
  static const maxXpPerMission = 100;

  /// Hard ceiling on the sum of previews granted in one calendar day —
  /// stops "infinite farming" by completing many trivial missions back to
  /// back (spec section 5). Enforced here by clamping against
  /// [xpAlreadyEarnedToday], which the caller tracks.
  static const maxDailyXpPreview = 300;

  static const maxCategoryMultiplier = 1.15;

  /// +2 XP per streak day, capped — consistency is rewarded, but a long
  /// streak can never dominate the formula (spec: "no unhealthy streak
  /// pressure").
  static const maxStreakBonus = 20;
  static const _streakBonusPerDay = 2;

  /// Deliberately flat and small: recovery missions matter for the user's
  /// wellbeing, not for out-competing anyone (spec section 5).
  static const maxRecoveryBonus = 10;

  /// A repeat of the same mission this recently is diminished further with
  /// each additional repeat, but never fully zeroed — the floor keeps the
  /// formula honest rather than punitive.
  static const _diminishingReturnsFloor = 0.2;

  static const Map<MissionDifficultyLevel, double> _difficultyMultipliers = {
    MissionDifficultyLevel.restorative: 0.6,
    MissionDifficultyLevel.easy: 1.0,
    MissionDifficultyLevel.moderate: 1.3,
    MissionDifficultyLevel.challenging: 1.6,
    MissionDifficultyLevel.advanced: 2.0,
  };

  static const Map<CategoryMasteryTier, double> _categoryTierMultipliers = {
    CategoryMasteryTier.beginner: 1.0,
    CategoryMasteryTier.practitioner: 1.05,
    CategoryMasteryTier.advanced: 1.1,
    CategoryMasteryTier.master: maxCategoryMultiplier,
  };

  static XpRewardEvaluation evaluate({
    required CompletedMissionSummary summary,
    required MissionHistorySnapshot snapshot,
    int xpAlreadyEarnedToday = 0,
  }) {
    final reasons = <String>[];

    final difficultyMultiplier = _difficultyMultipliers[summary.difficulty]!;
    reasons.add(
      '${summary.difficulty.name} difficulty applies a '
      '${difficultyMultiplier}x multiplier.',
    );

    final priorCategoryCompletions =
        snapshot.completionsByCategory[summary.category] ?? 0;
    final categoryTier = CategoryMasteryThresholds.tierFor(
      priorCategoryCompletions,
    );
    final categoryMultiplier = _categoryTierMultipliers[categoryTier]!;
    if (categoryMultiplier > 1.0) {
      reasons.add(
        '${categoryMasteryTierLabel(categoryTier)} tier in this category '
        'adds a ${categoryMultiplier}x multiplier.',
      );
    }

    final subtotal =
        (summary.baseXpHint * difficultyMultiplier * categoryMultiplier)
            .round();

    final consistencyBonus = (snapshot.currentStreakDays * _streakBonusPerDay)
        .clamp(0, maxStreakBonus);
    if (consistencyBonus > 0) {
      reasons.add(
        '+$consistencyBonus XP for a ${snapshot.currentStreakDays}-day streak.',
      );
    }

    final recoveryBonus = summary.recoveryMission ? maxRecoveryBonus : 0;
    if (recoveryBonus > 0) {
      reasons.add('+$recoveryBonus XP for showing up during recovery.');
    }

    final preDiminish = subtotal + consistencyBonus + recoveryBonus;

    final recentSameDefinitionCount =
        snapshot.completionsByDefinitionId[summary.definitionId] ?? 0;
    final diminishingFactor = recentSameDefinitionCount <= 0
        ? 1.0
        : (1 / (1 + 0.5 * recentSameDefinitionCount)).clamp(
            _diminishingReturnsFloor,
            1.0,
          );
    final postDiminish = (preDiminish * diminishingFactor).round();
    final diminishingPenalty = postDiminish - preDiminish;
    if (diminishingPenalty < 0) {
      reasons.add(
        "$diminishingPenalty XP: you've completed this exact mission "
        '$recentSameDefinitionCount time(s) recently, so it earns less each '
        'time.',
      );
    }

    var finalXpPreview = postDiminish.clamp(0, maxXpPerMission);
    if (postDiminish > maxXpPerMission) {
      reasons.add('Capped at the $maxXpPerMission XP per-mission limit.');
    }

    final remainingDailyAllowance = (maxDailyXpPreview - xpAlreadyEarnedToday)
        .clamp(0, maxDailyXpPreview);
    if (finalXpPreview > remainingDailyAllowance) {
      finalXpPreview = remainingDailyAllowance;
      reasons.add('Capped by today\'s $maxDailyXpPreview XP preview limit.');
    }

    return XpRewardEvaluation(
      missionInstanceId: summary.missionInstanceId,
      baseXp: summary.baseXpHint,
      difficultyMultiplier: difficultyMultiplier,
      categoryMultiplier: categoryMultiplier,
      consistencyBonus: consistencyBonus,
      recoveryBonus: recoveryBonus,
      penaltyAdjustments: diminishingPenalty,
      finalXpPreview: finalXpPreview,
      reasons: reasons,
      evaluationVersion: evaluationVersion,
    );
  }
}
