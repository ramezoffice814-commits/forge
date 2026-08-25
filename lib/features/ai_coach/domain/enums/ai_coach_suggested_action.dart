/// The complete, closed set of actions the AI is ever allowed to
/// *propose* (Roadmap Item 14 section 11: "AI may propose actions... but
/// action execution must go through existing deterministic use cases").
/// This enum IS the authority boundary at the type level: there is no
/// constructor path from raw AI provider output to app behavior that
/// skips it, and every one of these maps to a use case Forge already had
/// before the AI Coach existed — never a new capability introduced
/// *through* the AI layer.
enum AiCoachSuggestedAction {
  requestEasierMission,
  explainMission,
  openProgress,
  openLeaderboard,
  startMission;

  /// Parses a provider-supplied action identifier safely — an unknown or
  /// malformed string is `null`, never a thrown exception and never a
  /// guessed nearest match. Callers (`AiCoachResponseValidator`) drop
  /// anything that fails to parse rather than passing it through.
  static AiCoachSuggestedAction? tryParse(String raw) {
    for (final action in values) {
      if (action.name == raw) return action;
    }
    return null;
  }
}
