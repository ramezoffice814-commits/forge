import 'package:flutter/foundation.dart';

import '../../domain/entities/character_state.dart';
import '../../domain/entities/transmission_script.dart';

/// Presentation-level phase of the Daily Transmission experience. Distinct
/// from [CharacterState] (what the character itself is doing) — this is
/// the overall flow position.
enum TransmissionPhase {
  unavailable,
  preparing,
  incoming,
  entering,
  speaking,
  missionReveal,
  awaitingAcceptance,
  accepting,
  accepted,
  replaying,
  skipped,
  error,
}

const _unset = Object();

@immutable
class DailyTransmissionState {
  const DailyTransmissionState({
    this.phase = TransmissionPhase.preparing,
    this.script,
    this.dialogueIndex = -1,
    this.characterState = CharacterState.hidden,
    this.muted = false,
    this.ttsAvailable = true,
    this.reducedMotion = false,
    this.missionAccepted = false,
    this.offlineFallback = false,
    this.errorMessage,
  });

  final TransmissionPhase phase;
  final TransmissionScript? script;

  /// Index into `script.dialogueLines` of the line currently shown/spoken.
  /// `-1` before the first line has been reached.
  final int dialogueIndex;
  final CharacterState characterState;
  final bool muted;
  final bool ttsAvailable;
  final bool reducedMotion;
  final bool missionAccepted;

  /// True when the current [errorMessage] stems from being offline with no
  /// cached script, rather than a generic repository failure.
  final bool offlineFallback;
  final String? errorMessage;

  bool get hasReveal =>
      phase == TransmissionPhase.missionReveal ||
      phase == TransmissionPhase.awaitingAcceptance ||
      phase == TransmissionPhase.accepting ||
      phase == TransmissionPhase.accepted ||
      phase == TransmissionPhase.skipped;

  bool get canSkip =>
      phase == TransmissionPhase.incoming ||
      phase == TransmissionPhase.entering ||
      phase == TransmissionPhase.speaking;

  bool get canReplay =>
      phase == TransmissionPhase.speaking ||
      phase == TransmissionPhase.missionReveal ||
      phase == TransmissionPhase.awaitingAcceptance ||
      phase == TransmissionPhase.accepted ||
      phase == TransmissionPhase.skipped;

  bool get canAccept =>
      !missionAccepted &&
      (phase == TransmissionPhase.missionReveal ||
          phase == TransmissionPhase.awaitingAcceptance ||
          phase == TransmissionPhase.skipped);

  DailyTransmissionState copyWith({
    TransmissionPhase? phase,
    Object? script = _unset,
    int? dialogueIndex,
    CharacterState? characterState,
    bool? muted,
    bool? ttsAvailable,
    bool? reducedMotion,
    bool? missionAccepted,
    bool? offlineFallback,
    Object? errorMessage = _unset,
  }) {
    return DailyTransmissionState(
      phase: phase ?? this.phase,
      script: identical(script, _unset)
          ? this.script
          : script as TransmissionScript?,
      dialogueIndex: dialogueIndex ?? this.dialogueIndex,
      characterState: characterState ?? this.characterState,
      muted: muted ?? this.muted,
      ttsAvailable: ttsAvailable ?? this.ttsAvailable,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      missionAccepted: missionAccepted ?? this.missionAccepted,
      offlineFallback: offlineFallback ?? this.offlineFallback,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
