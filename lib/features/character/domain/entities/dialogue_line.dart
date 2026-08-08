import 'package:flutter/foundation.dart';

import 'character_state.dart';

/// One beat of spoken/subtitled dialogue inside a [TransmissionScript].
@immutable
class DialogueLine {
  const DialogueLine({
    required this.id,
    required this.text,
    required this.estimatedDuration,
    this.pauseAfter = Duration.zero,
    this.emotionalState,
    this.emphasisWords = const [],
  });

  final String id;
  final String text;

  /// Fallback pacing when TTS is unavailable or its completion signal can't
  /// be trusted — never used to cut a real utterance short, only to advance
  /// the subtitle when there is no audio driving it.
  final Duration estimatedDuration;
  final Duration pauseAfter;

  /// What the character should visually do while this line plays. `null`
  /// means "stay speaking" — most lines don't change the character's mood.
  final CharacterState? emotionalState;

  final List<String> emphasisWords;
}
