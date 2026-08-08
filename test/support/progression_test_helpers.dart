import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/progression/domain/entities/completed_mission_summary.dart';

const testProgressionUserId = 'test-user';

CompletedMissionSummary testCompletedSummary({
  String missionInstanceId = 'mission-1',
  String definitionId = 'def-1',
  String userId = testProgressionUserId,
  MissionCategory category = MissionCategory.fitness,
  MissionDifficultyLevel difficulty = MissionDifficultyLevel.easy,
  int baseXpHint = 20,
  int resolvedDurationMinutes = 10,
  bool recoveryMission = false,
  required DateTime completedAt,
}) {
  return CompletedMissionSummary(
    missionInstanceId: missionInstanceId,
    definitionId: definitionId,
    userId: userId,
    category: category,
    difficulty: difficulty,
    baseXpHint: baseXpHint,
    resolvedDurationMinutes: resolvedDurationMinutes,
    recoveryMission: recoveryMission,
    completedAt: completedAt,
  );
}
