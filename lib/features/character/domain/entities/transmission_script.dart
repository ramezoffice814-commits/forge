import 'package:flutter/foundation.dart';

import '../../../dashboard/domain/entities/mission_preview.dart'
    show MissionDifficulty;
import 'character_id.dart';
import 'dialogue_line.dart';

/// A single deterministic Daily Transmission: the character's dialogue plus
/// the mission it reveals. Produced by [TransmissionRepository] — real
/// AI-generated scripts are out of scope for this phase, every script is
/// hand-authored mock data.
@immutable
class TransmissionScript {
  const TransmissionScript({
    required this.id,
    required this.characterId,
    required this.date,
    required this.introLabel,
    required this.dialogueLines,
    required this.missionTitle,
    required this.missionDescription,
    required this.category,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.xpReward,
    required this.requiresProof,
    required this.completionConditions,
    required this.accessibilitySummary,
    this.closingDialogue,
  });

  final String id;
  final CharacterId characterId;
  final DateTime date;
  final String introLabel;
  final List<DialogueLine> dialogueLines;

  final String missionTitle;
  final String missionDescription;
  final String category;
  final MissionDifficulty difficulty;
  final int estimatedMinutes;
  final int xpReward;
  final bool requiresProof;
  final List<String> completionConditions;

  final List<DialogueLine>? closingDialogue;

  /// One concise sentence a screen reader can announce for the whole
  /// transmission without needing to step through every dialogue line.
  final String accessibilitySummary;

  String get fullTranscript => dialogueLines.map((l) => l.text).join('\n\n');
}
