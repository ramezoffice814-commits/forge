import 'package:flutter/foundation.dart';

import '../enums/ai_coach_task.dart';
import 'ai_coach_context.dart';

/// One AI generation request — the task determines which prompt version
/// (`AiCoachPromptTemplates`) and response shape are expected;
/// [context] is always the same narrow, allow-listed type regardless of
/// task (spec section 5 applies uniformly, not per-task).
@immutable
class AiCoachRequest {
  const AiCoachRequest({
    required this.task,
    required this.context,
    required this.requestId,
    this.contextVersion,
  });

  final AiCoachTask task;
  final AiCoachContext context;

  /// For tracing/observability — never used for authority of any kind
  /// (mirrors `RequestIdGenerator`'s existing "trace id, not idempotency
  /// key" distinction elsewhere in this codebase).
  final String requestId;

  /// A fingerprint of whatever makes this request's context distinct
  /// (see `AiCoachCacheStore`'s own doc comment) — `null` for tasks that
  /// are never cached (e.g. `coachChat`).
  final String? contextVersion;
}
