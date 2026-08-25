/// Every way an AI generation attempt can fail to produce a usable
/// result — never a raw exception surfaced to the UI (Roadmap Item 14
/// section 14: "AI must never become a single point of failure").
/// Every variant has exactly one correct UI response: show the
/// deterministic fallback for this task, never an error screen — a
/// failed AI call is a degraded-but-functional state, not a broken one.
enum AiCoachFailureReason {
  /// [AiPrivacyLevel.disabled] — not actually a failure, but routed
  /// through the same fallback path for a uniform "no AI content" UI.
  disabledByUser,
  offline,
  timeout,
  rateLimited,
  providerError,

  /// The provider returned something, but it didn't parse into a valid
  /// [AiCoachResponse] or failed [AiCoachSafetyFilter] — treated
  /// identically to a provider error from the UI's perspective; the
  /// distinction only matters for observability.
  malformedResponse,
  unauthenticated,
}

class AiCoachFailure implements Exception {
  const AiCoachFailure(this.reason, [this.debugMessage]);

  final AiCoachFailureReason reason;

  /// Never shown to the user — logging/debugging only. See
  /// `AiCoachFallbackTemplates` for the actual user-facing copy, which
  /// never varies by reason (spec section 13: never leak provider/
  /// system detail).
  final String? debugMessage;

  @override
  String toString() =>
      'AiCoachFailure(${reason.name}${debugMessage != null ? ': $debugMessage' : ''})';
}
