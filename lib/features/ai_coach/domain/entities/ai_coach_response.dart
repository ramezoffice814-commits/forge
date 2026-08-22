import 'package:flutter/foundation.dart';

import '../enums/ai_coach_suggested_action.dart';

/// A validated, safe AI generation result (Roadmap Item 14 section 12:
/// "structured output... validate responses"). The only way to obtain an
/// instance is [AiCoachResponse.tryParse] — there is no public
/// constructor a caller could use to fabricate a response from
/// unvalidated data, mirroring `RawBackendResponse.fromBackendAdapter`'s
/// "the type itself is the proof this went through the real path"
/// pattern from `core/backend`.
@immutable
class AiCoachResponse {
  const AiCoachResponse._({
    required this.message,
    required this.reasoningSummary,
    required this.suggestedActions,
  });

  final String message;

  /// Short, optional — "why" in one sentence. Never the full provider
  /// chain-of-thought (never requested from the provider in the first
  /// place — see the prompt templates).
  final String? reasoningSummary;

  /// Already filtered to only the actions [AiCoachSuggestedAction]
  /// recognizes — an unparseable entry is dropped, never surfaced as an
  /// error (spec section 12: "reject malformed/unexpected provider
  /// output safely").
  final List<AiCoachSuggestedAction> suggestedActions;

  static const int _maxMessageLength = 2000;

  /// Parses and validates a raw provider JSON object. Returns `null` for
  /// anything malformed — missing/wrong-typed `message`, or a message
  /// over the length cap (spec section 17: "response-size cap"). Unknown
  /// JSON keys are ignored (forward-compatible, never a parse failure).
  static AiCoachResponse? tryParse(Map<String, Object?> json) {
    final message = json['message'];
    if (message is! String || message.isEmpty) return null;
    if (message.length > _maxMessageLength) return null;

    final reasoningRaw = json['reasoningSummary'];
    final reasoning = reasoningRaw is String && reasoningRaw.isNotEmpty
        ? reasoningRaw
        : null;

    final actionsRaw = json['suggestedActions'];
    final actions = <AiCoachSuggestedAction>[];
    if (actionsRaw is List) {
      for (final entry in actionsRaw) {
        if (entry is! String) continue;
        final parsed = AiCoachSuggestedAction.tryParse(entry);
        if (parsed != null) actions.add(parsed);
      }
    }

    return AiCoachResponse._(
      message: message,
      reasoningSummary: reasoning,
      suggestedActions: List.unmodifiable(actions),
    );
  }

  /// Test/fallback-construction seam — deliberately separate from
  /// [tryParse] so fallback templates never pretend to have come from a
  /// real provider response.
  factory AiCoachResponse.local(
    String message, {
    List<AiCoachSuggestedAction> suggestedActions = const [],
  }) => AiCoachResponse._(
    message: message,
    reasoningSummary: null,
    suggestedActions: suggestedActions,
  );
}
