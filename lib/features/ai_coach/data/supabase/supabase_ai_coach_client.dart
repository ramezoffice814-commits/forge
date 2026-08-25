import '../../../../core/backend/edge_functions_client.dart';
import '../../domain/entities/ai_coach_request.dart';
import '../../domain/entities/ai_coach_response.dart';
import '../../domain/failures/ai_coach_failure.dart';
import '../ai_coach_client.dart';

/// Calls the server-side `ai-coach` Edge Function (Roadmap Item 14
/// section 4) — reuses the existing `EdgeFunctionsClient` seam
/// `SupabaseBackendClient` already depends on, rather than a second,
/// parallel HTTP layer. The client never sees a provider API key, a
/// system prompt, or any provider credential — those exist only inside
/// the Edge Function's own runtime environment (see
/// `supabase/functions/ai-coach/index.ts`). The request body sent here
/// is exactly [AiCoachContext]'s own allow-listed fields — there is no
/// path for this class to smuggle along anything the context object
/// doesn't already carry.
class SupabaseAiCoachClient implements AiCoachClient {
  const SupabaseAiCoachClient(this._functions);

  final EdgeFunctionsClient _functions;

  @override
  Future<AiCoachResponse> generate(AiCoachRequest request) async {
    final context = request.context;
    final Map<String, Object?> data;
    try {
      data = await _functions.invoke('ai-coach', {
        'task': request.task.name,
        'requestId': request.requestId,
        'context': {
          'displayName': context.displayName,
          'currentMissionTitle': context.currentMissionTitle,
          'currentMissionCategory': context.currentMissionCategory,
          'currentMissionDifficulty': context.currentMissionDifficulty,
          'availableMinutesToday': context.availableMinutesToday,
          'recentCompletionRatePercent': context.recentCompletionRatePercent,
          'activeDaysThisWeek': context.activeDaysThisWeek,
          'currentLevel': context.currentLevel,
          'currentTitle': context.currentTitle,
          'currentLeagueName': context.currentLeagueName,
          'recentCategoryUsage': context.recentCategoryUsage,
          'consistencySummary': context.consistencySummary,
          'isRecoveryMode': context.isRecoveryMode,
          'preferredCategories': context.preferredCategories,
          'dislikedCategories': context.dislikedCategories,
          'goalFocusLabel': context.goalFocusLabel,
          'coachingTone': context.coachingTone.name,
          'userMessage': context.userMessage,
        },
      });
    } on EdgeFunctionCallFailure catch (e) {
      throw AiCoachFailure(
        e.statusCode == 429
            ? AiCoachFailureReason.rateLimited
            : AiCoachFailureReason.providerError,
        e.message,
      );
    }

    final response = AiCoachResponse.tryParse(data);
    if (response == null) {
      throw const AiCoachFailure(AiCoachFailureReason.malformedResponse);
    }
    return response;
  }
}
