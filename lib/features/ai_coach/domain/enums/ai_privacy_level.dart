/// User-controlled AI privacy preference (Roadmap Item 14 section 23).
/// `disabled` is a real, fully-supported mode — Forge's mission/
/// progression/competition systems never depend on this feature existing
/// at all, so turning it off removes AI surfaces cleanly rather than
/// degrading them.
enum AiPrivacyLevel {
  /// The full allow-listed [AiCoachContext] (still never the forbidden
  /// fields — see that class's own doc comment) may be sent.
  fullContext,

  /// A deliberately smaller subset — display name and the current
  /// mission's public facts only, no progression/competition/behavioral
  /// aggregates. Good enough for mission explanation; too little for a
  /// meaningful weekly recap (that task is disabled at this level — see
  /// [AiCoachContextBuilder]).
  limitedContext,

  /// No AI network call is ever made. Every AI surface renders its
  /// deterministic fallback copy instead, indistinguishable in
  /// functionality from a provider outage.
  disabled,
}
