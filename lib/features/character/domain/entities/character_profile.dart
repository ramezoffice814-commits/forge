import 'package:flutter/foundation.dart';

import 'character_id.dart';
import 'character_state.dart';

/// Default speech settings for a character's voice — passed straight to
/// [TtsService.setRate]/[TtsService.setPitch]/[TtsService.setVolume].
/// Values are in the ranges the `flutter_tts` plugin expects: rate/volume
/// 0.0–1.0, pitch 0.5–2.0 (1.0 is neutral).
@immutable
class VoiceSettings {
  const VoiceSettings({
    required this.rate,
    required this.pitch,
    required this.volume,
  });

  final double rate;
  final double pitch;
  final double volume;
}

/// Static identity/presentation data for a character — never mutated at
/// runtime, unlike [CharacterState] which changes constantly.
@immutable
class CharacterProfile {
  const CharacterProfile({
    required this.id,
    required this.displayName,
    required this.title,
    required this.shortDescription,
    required this.accentTheme,
    required this.speakingStyle,
    required this.defaultVoiceSettings,
    required this.supportedStates,
    required this.accessibilityDescription,
  });

  final CharacterId id;
  final String displayName;
  final String title;
  final String shortDescription;

  /// Free-form theme key (e.g. `'purple'`) — kept as data rather than a
  /// [Color] so this stays a pure Flutter-free domain entity; presentation
  /// widgets map it to actual [ForgeTokens] colors.
  final String accentTheme;
  final String speakingStyle;
  final VoiceSettings defaultVoiceSettings;
  final Set<CharacterState> supportedStates;
  final String accessibilityDescription;

  static const watcher = CharacterProfile(
    id: CharacterId.watcher,
    displayName: 'The Watcher',
    title: 'Keeper of the Forge',
    shortDescription:
        'A quiet presence who delivers your daily trial and says little '
        'else.',
    accentTheme: 'purple',
    speakingStyle: 'calm, slow, measured',
    defaultVoiceSettings: VoiceSettings(rate: 0.42, pitch: 0.88, volume: 1),
    supportedStates: {
      CharacterState.hidden,
      CharacterState.incoming,
      CharacterState.entering,
      CharacterState.idle,
      CharacterState.speaking,
      CharacterState.thinking,
      CharacterState.missionRevealed,
      CharacterState.missionAccepted,
      CharacterState.proud,
      CharacterState.concerned,
      CharacterState.completed,
      CharacterState.disappearing,
      CharacterState.unavailable,
    },
    accessibilityDescription:
        'The Watcher: a dark, partially obscured silhouette lit by a soft '
        'purple rim light, framed inside a transmission window.',
  );
}
