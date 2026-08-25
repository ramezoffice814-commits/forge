import '../domain/entities/ai_coach_request.dart';
import '../domain/entities/ai_coach_response.dart';
import '../domain/failures/ai_coach_failure.dart';

/// The one seam every AI provider implementation goes through (Roadmap
/// Item 14 section 2: "do not couple domain code directly to one AI
/// provider SDK") — same shape as `BackendClient`/`EdgeFunctionsClient`
/// in `core/backend`. `AiCoachRepository` is the only caller; nothing
/// presentation-layer talks to this directly.
///
/// Throws [AiCoachFailure] on any failure — never returns a partial or
/// best-guess [AiCoachResponse]. A successful return is already validated
/// (see `AiCoachResponse.tryParse`); the safety filter runs one layer up,
/// in `AiCoachRepository`, so it applies uniformly regardless of which
/// client produced the response.
abstract class AiCoachClient {
  Future<AiCoachResponse> generate(AiCoachRequest request);
}
