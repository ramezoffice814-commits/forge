import 'package:flutter/foundation.dart';

import '../../../missions/domain/enums/mission_category.dart';
import '../../../missions/domain/enums/mission_difficulty_level.dart';
import '../enums/completion_quality.dart';
import '../enums/completion_validation_state.dart';
import '../enums/competition_integrity_state.dart';
import '../enums/reward_authority_state.dart';

/// The one narrow bridge into competition — mirrors how `progression`
/// never reads a raw `MissionAggregate`/`MissionEvent` directly (see
/// `CompletedMissionSummary`'s own doc comment). Competition never touches
/// mission or progression internals; it only ever sees this already-shaped,
/// explicitly-provisional fact.
///
/// Every trust-sensitive field here is a state, not a boolean "is this
/// good?" — so `ForgeCompetitiveScorePolicy` can explain exactly why a
/// completion scored what it did, rather than silently discarding data.
@immutable
class CompetitiveCompletionSummary {
  const CompetitiveCompletionSummary({
    required this.missionInstanceId,
    required this.userId,
    required this.completedAt,
    required this.category,
    required this.difficulty,
    required this.provisionalXp,
    required this.recoveryMission,
    required this.repeatedMissionCount,
    required this.completionQuality,
    required this.validationState,
    required this.eventIntegrityState,
    required this.rewardAuthorityState,
  });

  final String missionInstanceId;
  final String userId;
  final DateTime completedAt;
  final MissionCategory category;
  final MissionDifficultyLevel difficulty;

  /// Carried over from `XpRewardEvaluation.finalXpPreview` — display
  /// context only; the competitive score is never derived from XP (see
  /// module-level trust-boundary notes).
  final int provisionalXp;

  final bool recoveryMission;

  /// How many times this same mission definition/family has already been
  /// completed recently — the raw signal `ForgeCompetitiveScorePolicy`'s
  /// repetition penalty is computed from.
  final int repeatedMissionCount;

  final CompletionQuality completionQuality;
  final CompletionValidationState validationState;
  final CompetitionIntegrityState eventIntegrityState;

  /// Always [RewardAuthorityState.localPreviewOnly] or
  /// [RewardAuthorityState.pendingServerConfirmation] in this phase —
  /// nothing in this module ever constructs one as confirmed.
  final RewardAuthorityState rewardAuthorityState;

  CompetitiveCompletionSummary withEventIntegrityState(
    CompetitionIntegrityState state,
  ) {
    return CompetitiveCompletionSummary(
      missionInstanceId: missionInstanceId,
      userId: userId,
      completedAt: completedAt,
      category: category,
      difficulty: difficulty,
      provisionalXp: provisionalXp,
      recoveryMission: recoveryMission,
      repeatedMissionCount: repeatedMissionCount,
      completionQuality: completionQuality,
      validationState: validationState,
      eventIntegrityState: state,
      rewardAuthorityState: rewardAuthorityState,
    );
  }
}
