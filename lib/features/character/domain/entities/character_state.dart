/// Visual/behavioral state a character render can be in. Distinct from the
/// Daily Transmission presentation phase (see `DailyTransmissionPhase`) —
/// this is only what the character itself is doing, so a future real Rive
/// state machine has a stable, narrow contract to implement against.
enum CharacterState {
  hidden,
  incoming,
  entering,
  idle,
  speaking,
  thinking,
  missionRevealed,
  missionAccepted,
  proud,
  concerned,
  completed,
  disappearing,
  unavailable,
}
