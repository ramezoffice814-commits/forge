import 'package:flutter/foundation.dart';

import '../entities/level_definition.dart';
import '../entities/user_progression_profile.dart';
import '../policies/level_policy.dart';

/// Merges a server-confirmed reward into a [UserProgressionProfile] —
/// the one place "confirmed XP comes only from server result" (spec
/// section 9) is actually enforced for progression. Never called with
/// data that didn't genuinely come from a [MissionSubmissionServerResult]
/// — see `ConfirmedMissionReward` in `mission_command_reconciliation.dart`,
/// which only exists on an accepted submission.
@immutable
class ProgressionReconciliationResult {
  const ProgressionReconciliationResult({
    required this.profile,
    required this.newlyUnlockedAchievementIds,
  });

  final UserProgressionProfile profile;

  /// Achievement ids the server reported as unlocked that were **not**
  /// already in [UserProgressionProfile.unlockedAchievementIds] before
  /// this reconciliation — the only ones a caller should celebrate (spec
  /// section 10: "prevent duplicate unlock presentation").
  final List<String> newlyUnlockedAchievementIds;
}

abstract final class ProgressionReconciliation {
  /// [confirmedTotalXp] is the server's authoritative running total
  /// (`user_progression.confirmed_xp` — never a delta this function has
  /// to add up itself, which is what makes it safe to call even after a
  /// missed intermediate update). The portion of local [provisionalXp]
  /// that this reward accounts for ([confirmedXpDelta]) is subtracted
  /// out of the provisional bucket so the same XP is never shown as both
  /// provisional and confirmed at once; whatever provisional XP remains
  /// (from missions not yet submitted/confirmed) is left untouched.
  ///
  /// [currentLevel] is recomputed locally via [LevelPolicy] against
  /// [catalog] rather than trusted verbatim from the server response —
  /// both sides run the identical formula (`xp_policy_v1`'s level
  /// lookup mirrors `LevelPolicy`/`LevelCatalog` exactly), so recomputing
  /// here preserves [UserProgressionProfile.currentLevel]'s existing
  /// "preview-inclusive" invariant (confirmed + remaining provisional)
  /// rather than introducing a second, narrower meaning for the field.
  static UserProgressionProfile applyConfirmedReward({
    required UserProgressionProfile current,
    required int confirmedXpDelta,
    required int confirmedTotalXp,
    required List<LevelDefinition> catalog,
    required DateTime now,
  }) {
    final remainingProvisional = (current.provisionalXp - confirmedXpDelta)
        .clamp(0, current.provisionalXp);
    final previewTotal = confirmedTotalXp + remainingProvisional;

    return current.copyWith(
      totalConfirmedXp: confirmedTotalXp,
      provisionalXp: remainingProvisional,
      currentLevel: LevelPolicy.levelFor(previewTotal, catalog).levelNumber,
      updatedAt: now,
    );
  }

  static ProgressionReconciliationResult mergeConfirmedAchievements({
    required UserProgressionProfile current,
    required List<String> confirmedAchievementIds,
  }) {
    final newlyUnlocked = confirmedAchievementIds
        .where((id) => !current.unlockedAchievementIds.contains(id))
        .toList(growable: false);

    if (newlyUnlocked.isEmpty) {
      return ProgressionReconciliationResult(
        profile: current,
        newlyUnlockedAchievementIds: const [],
      );
    }

    return ProgressionReconciliationResult(
      profile: current.copyWith(
        unlockedAchievementIds: {
          ...current.unlockedAchievementIds,
          ...newlyUnlocked,
        },
      ),
      newlyUnlockedAchievementIds: newlyUnlocked,
    );
  }
}
