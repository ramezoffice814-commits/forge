import 'package:flutter/foundation.dart';

import '../enums/mission_category.dart';
import '../enums/mission_difficulty_level.dart';
import '../enums/proof_policy.dart';
import '../progress/mission_progress_definition.dart';
import 'mission_selection_result.dart';

enum MissionInstanceStatus {
  notStarted,
  viewed,
  accepted,
  readyToSubmit,
  completed,
}

/// The one authoritative "today's mission" object for a local session —
/// produced once from a [MissionSelectionResult] and then handed to both
/// the Dashboard and the Daily Transmission experience, so they can never
/// disagree about title/duration/category/difficulty/XP.
@immutable
class MissionInstance {
  const MissionInstance({
    required this.instanceId,
    required this.definitionId,
    required this.assignedDate,
    required this.title,
    required this.description,
    required this.category,
    required this.resolvedDifficulty,
    required this.resolvedDuration,
    required this.xpHint,
    required this.completionConditions,
    required this.proofPolicy,
    required this.selectionReasons,
    required this.engineVersion,
    required this.progressDefinition,
    this.accessibilityAlternativeUsed = false,
    this.recoveryMission = false,
    this.status = MissionInstanceStatus.notStarted,
  });

  factory MissionInstance.fromSelectionResult(
    MissionSelectionResult result, {
    required String instanceId,
    required DateTime assignedDate,
  }) {
    final mission = result.selectedMission;
    return MissionInstance(
      instanceId: instanceId,
      definitionId: mission.id,
      assignedDate: assignedDate,
      title: mission.title,
      description: mission.description,
      category: mission.category,
      resolvedDifficulty: result.resolvedDifficulty,
      resolvedDuration: result.resolvedDuration,
      xpHint: mission.baseXpHint,
      completionConditions: mission.completionConditions,
      proofPolicy: mission.proofPolicy,
      selectionReasons: result.selectionReasons,
      engineVersion: result.engineVersion,
      progressDefinition: MissionProgressDefinition.fromCatalog(
        type: mission.progressType,
        target: mission.progressTarget,
        resolvedMinutes: result.resolvedDuration,
        completionConditions: mission.completionConditions,
      ),
      accessibilityAlternativeUsed: result.accessibilityAlternativeUsed,
      recoveryMission: result.recoveryApplied,
    );
  }

  final String instanceId;
  final String definitionId;
  final DateTime assignedDate;

  final String title;
  final String description;
  final MissionCategory category;
  final MissionDifficultyLevel resolvedDifficulty;
  final int resolvedDuration;

  /// Display-only. Not authoritative — see the engine's trust-boundary
  /// documentation; a future backend must validate before granting XP.
  final int xpHint;

  final List<String> completionConditions;
  final ProofPolicy proofPolicy;
  final List<String> selectionReasons;
  final String engineVersion;

  /// What "progress" means for this specific mission — see
  /// `MissionAggregate`, which uses this to seed the initial progress
  /// state and to validate updates/completion.
  final MissionProgressDefinition progressDefinition;

  final bool accessibilityAlternativeUsed;
  final bool recoveryMission;

  /// Superseded by `MissionAggregate.lifecycleState` (event-derived) as of
  /// the mission lifecycle phase — kept only because `MissionPreview`'s
  /// legacy display mapping still reads it as a fallback before any events
  /// exist. Never treat this as authoritative once an aggregate exists.
  final MissionInstanceStatus status;

  MissionInstance copyWith({MissionInstanceStatus? status}) {
    return MissionInstance(
      instanceId: instanceId,
      definitionId: definitionId,
      assignedDate: assignedDate,
      title: title,
      description: description,
      category: category,
      resolvedDifficulty: resolvedDifficulty,
      resolvedDuration: resolvedDuration,
      xpHint: xpHint,
      completionConditions: completionConditions,
      proofPolicy: proofPolicy,
      selectionReasons: selectionReasons,
      engineVersion: engineVersion,
      progressDefinition: progressDefinition,
      accessibilityAlternativeUsed: accessibilityAlternativeUsed,
      recoveryMission: recoveryMission,
      status: status ?? this.status,
    );
  }
}
