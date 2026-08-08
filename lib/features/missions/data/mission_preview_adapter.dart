import '../../dashboard/domain/entities/mission_preview.dart';
import '../domain/entities/mission_instance.dart';
import '../domain/enums/mission_category.dart';
import '../domain/enums/mission_difficulty_level.dart';
import '../domain/enums/proof_policy.dart';

/// Maps the engine's 5-level [MissionDifficultyLevel] down to the existing
/// Dashboard/Transmission UI's 3-level [MissionDifficulty] — the UI never
/// needed to change for this phase, only the data feeding it did.
MissionDifficulty toLegacyDifficulty(MissionDifficultyLevel level) {
  return switch (level) {
    MissionDifficultyLevel.restorative ||
    MissionDifficultyLevel.easy => MissionDifficulty.easy,
    MissionDifficultyLevel.moderate => MissionDifficulty.moderate,
    MissionDifficultyLevel.challenging ||
    MissionDifficultyLevel.advanced => MissionDifficulty.hard,
  };
}

MissionStatus _statusFromInstance(MissionInstanceStatus status) {
  return switch (status) {
    MissionInstanceStatus.notStarted => MissionStatus.notStarted,
    MissionInstanceStatus.viewed => MissionStatus.viewed,
    MissionInstanceStatus.accepted => MissionStatus.accepted,
    MissionInstanceStatus.readyToSubmit => MissionStatus.readyToSubmit,
    MissionInstanceStatus.completed => MissionStatus.completed,
  };
}

/// The single adapter Dashboard uses to turn the engine's [MissionInstance]
/// into the `MissionPreview` its existing widgets already know how to
/// render — this is what makes "one authoritative instance, two
/// presentations" possible without touching `TodayMissionCard` or
/// `MissionRevealPanel`.
MissionPreview missionPreviewFromInstance(
  MissionInstance instance, {
  required bool transmissionAvailable,
  String characterName = 'The Watcher',
}) {
  return MissionPreview(
    id: instance.instanceId,
    title: instance.title,
    subtitle: instance.description,
    category: missionCategoryLabel(instance.category),
    difficulty: toLegacyDifficulty(instance.resolvedDifficulty),
    estimatedMinutes: instance.resolvedDuration,
    xpReward: instance.xpHint,
    status: _statusFromInstance(instance.status),
    transmissionAvailable: transmissionAvailable,
    requiresProof: instance.proofPolicy != ProofPolicy.none,
    characterName: characterName,
    completionConditions: instance.completionConditions,
    selectionReasons: instance.selectionReasons,
  );
}
