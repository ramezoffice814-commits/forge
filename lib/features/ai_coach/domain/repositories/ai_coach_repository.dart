import '../entities/ai_coach_request.dart';
import '../entities/ai_coach_response.dart';

/// The one entry point every use case in this module calls through —
/// never `AiCoachClient` directly. Guarantees a response is *always*
/// returned (never throws): a disabled/offline/failed/unsafe generation
/// resolves to the deterministic fallback for that task, wrapped in the
/// same [AiCoachResponse] shape so callers never need a separate
/// success/failure branch just to render something (spec section 14).
abstract class AiCoachRepository {
  Future<AiCoachResponse> generate(AiCoachRequest request);
}
