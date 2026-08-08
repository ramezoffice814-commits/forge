import 'package:flutter/foundation.dart';

import '../enums/mission_category.dart';
import '../enums/mission_difficulty_level.dart';
import 'mission_instance.dart';

/// What the character/transmission system is allowed to know about the
/// selected mission — a read-only presentation of the engine's decision.
/// The character never chooses or re-scores anything; it only narrates
/// this. See `MissionInstance` for the authoritative record this is built
/// from.
@immutable
class CharacterMissionContext {
  const CharacterMissionContext({
    required this.characterId,
    required this.userDisplayName,
    required this.missionTitle,
    required this.missionDescription,
    required this.difficulty,
    required this.duration,
    required this.category,
    required this.recoveryMode,
    required this.selectionReasonSummary,
    required this.safeTone,
    this.recentPositivePattern,
    this.dialogueVariables = const {},
  });

  factory CharacterMissionContext.fromInstance(
    MissionInstance instance, {
    required String characterId,
    required String userDisplayName,
    String? recentPositivePattern,
  }) {
    return CharacterMissionContext(
      characterId: characterId,
      userDisplayName: userDisplayName,
      missionTitle: instance.title,
      missionDescription: instance.description,
      difficulty: instance.resolvedDifficulty,
      duration: instance.resolvedDuration,
      category: instance.category,
      recoveryMode: instance.recoveryMission,
      selectionReasonSummary: instance.selectionReasons.isEmpty
          ? null
          : instance.selectionReasons.first,
      recentPositivePattern: recentPositivePattern,
      safeTone: true,
    );
  }

  final String characterId;
  final String userDisplayName;
  final String missionTitle;
  final String missionDescription;
  final MissionDifficultyLevel difficulty;
  final int duration;
  final MissionCategory category;
  final bool recoveryMode;
  final String? selectionReasonSummary;

  /// e.g. "two days of consistency" — omitted entirely rather than
  /// fabricated when there's nothing genuine to point to.
  final String? recentPositivePattern;

  /// Always true in this phase — a hook for a future tone-classifier, not
  /// a real check yet.
  final bool safeTone;

  final Map<String, String> dialogueVariables;
}
