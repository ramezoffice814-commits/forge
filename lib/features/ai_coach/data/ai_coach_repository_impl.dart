import '../domain/entities/ai_coach_request.dart';
import '../domain/entities/ai_coach_response.dart';
import '../domain/enums/ai_privacy_level.dart';
import '../domain/failures/ai_coach_failure.dart';
import '../domain/repositories/ai_coach_repository.dart';
import '../domain/services/ai_coach_fallback_templates.dart';
import '../domain/services/ai_coach_rate_limiter.dart';
import '../domain/services/ai_coach_safety_filter.dart';
import 'ai_coach_cache_store.dart';
import 'ai_coach_client.dart';

/// Orchestrates the full request path (Roadmap Item 14): privacy check
/// → cache lookup → rate limit → timeout-bounded client call → safety
/// filter → cache write → fallback on any failure. This is the *only*
/// class in the module allowed to decide "show the fallback instead" —
/// every other layer either produces a validated response or throws.
class AiCoachRepositoryImpl implements AiCoachRepository {
  AiCoachRepositoryImpl({
    required AiCoachClient client,
    required AiCoachCacheStore cacheStore,
    required AiPrivacyLevel Function() privacyLevel,
    AiCoachRateLimiter? rateLimiter,
    Duration timeout = const Duration(seconds: 12),
  }) : _client = client,
       _cacheStore = cacheStore,
       _privacyLevel = privacyLevel,
       _rateLimiter = rateLimiter ?? AiCoachRateLimiter(),
       _timeout = timeout;

  final AiCoachClient _client;
  final AiCoachCacheStore _cacheStore;
  final AiPrivacyLevel Function() _privacyLevel;
  final AiCoachRateLimiter _rateLimiter;
  final Duration _timeout;

  @override
  Future<AiCoachResponse> generate(AiCoachRequest request) async {
    if (_privacyLevel() == AiPrivacyLevel.disabled) {
      return AiCoachFallbackTemplates.forTask(request.task, request.context);
    }

    final contextVersion = request.contextVersion;
    if (contextVersion != null) {
      final cached = await _cacheStore.load(request.task, contextVersion);
      if (cached != null) return cached;
    }

    if (!_rateLimiter.allowsRequest) {
      return AiCoachFallbackTemplates.forTask(request.task, request.context);
    }

    try {
      _rateLimiter.record();
      final response = await _client.generate(request).timeout(_timeout);

      if (AiCoachSafetyFilter.isUnsafe(response)) {
        return AiCoachFallbackTemplates.forTask(request.task, request.context);
      }

      if (contextVersion != null) {
        await _cacheStore.save(request.task, contextVersion, response);
      }
      return response;
    } on AiCoachFailure {
      return AiCoachFallbackTemplates.forTask(request.task, request.context);
    } catch (_) {
      // Timeout, network error, or anything else a provider/client
      // implementation could throw — never propagated (spec section 14:
      // "AI must never become a single point of failure").
      return AiCoachFallbackTemplates.forTask(request.task, request.context);
    }
  }
}
