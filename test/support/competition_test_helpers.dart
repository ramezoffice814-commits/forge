import 'package:forge/features/competition/domain/entities/competitive_completion_summary.dart';
import 'package:forge/features/competition/domain/enums/completion_quality.dart';
import 'package:forge/features/competition/domain/enums/completion_validation_state.dart';
import 'package:forge/features/competition/domain/enums/competition_integrity_state.dart';
import 'package:forge/features/competition/domain/enums/reward_authority_state.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';

const testCompetitionUserId = 'test-user';

CompetitiveCompletionSummary testCompetitiveSummary({
  String missionInstanceId = 'mission-1',
  String userId = testCompetitionUserId,
  required DateTime completedAt,
  MissionCategory category = MissionCategory.fitness,
  MissionDifficultyLevel difficulty = MissionDifficultyLevel.easy,
  int provisionalXp = 20,
  bool recoveryMission = false,
  int repeatedMissionCount = 0,
  CompletionQuality completionQuality = CompletionQuality.standard,
  CompletionValidationState validationState = CompletionValidationState.valid,
  CompetitionIntegrityState eventIntegrityState =
      CompetitionIntegrityState.clean,
  RewardAuthorityState rewardAuthorityState =
      RewardAuthorityState.localPreviewOnly,
}) {
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
    eventIntegrityState: eventIntegrityState,
    rewardAuthorityState: rewardAuthorityState,
  );
}
