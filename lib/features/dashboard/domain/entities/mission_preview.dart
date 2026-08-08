import 'package:flutter/foundation.dart';

/// Where the (not-yet-built) mission flow would take a user next. Distinct
/// from "accepted/submitted/completed" in a real mission record — this is
/// only what the dashboard needs to pick a primary-action label.
enum MissionStatus {
  notStarted,
  viewed,
  accepted,
  readyToSubmit,
  completed,
  unavailableOffline,
}

enum MissionDifficulty { easy, moderate, hard }

/// Today's mission as the dashboard needs to know it — not the mission
/// flow itself (accept/submit/proof-upload land in a later roadmap item).
@immutable
class MissionPreview {
  const MissionPreview({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.xpReward,
    required this.status,
    required this.transmissionAvailable,
    required this.requiresProof,
    this.characterName,
    this.completionConditions = const [],
    this.selectionReasons = const [],
  });

  final String id;
  final String title;
  final String subtitle;
  final String category;
  final MissionDifficulty difficulty;
  final int estimatedMinutes;
  final int xpReward;
  final MissionStatus status;
  final String? characterName;
  final bool transmissionAvailable;
  final bool requiresProof;

  /// Optional — populated when the preview was adapted from a
  /// `MissionInstance` (see `missions/data/mission_preview_adapter.dart`).
  final List<String> completionConditions;

  /// Optional, engine-provided, already-sanitized "why this mission" copy —
  /// see `MissionExplanationPanel`. Empty for previews not built from the
  /// mission-selection engine.
  final List<String> selectionReasons;

  MissionPreview copyWith({MissionStatus? status}) {
    return MissionPreview(
      id: id,
      title: title,
      subtitle: subtitle,
      category: category,
      difficulty: difficulty,
      estimatedMinutes: estimatedMinutes,
      xpReward: xpReward,
      status: status ?? this.status,
      transmissionAvailable: transmissionAvailable,
      requiresProof: requiresProof,
      characterName: characterName,
      completionConditions: completionConditions,
      selectionReasons: selectionReasons,
    );
  }
}
