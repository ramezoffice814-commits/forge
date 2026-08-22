import '../../../../core/backend/request_id_generator.dart';
import '../entities/ai_coach_request.dart';
import '../entities/ai_coach_response.dart';
import '../entities/ai_personalization_profile.dart';
import '../enums/ai_coach_task.dart';
import '../enums/ai_privacy_level.dart';
import '../repositories/ai_coach_repository.dart';
import '../services/ai_coach_context_builder.dart';
import '../services/ai_coach_fallback_templates.dart';

/// Roadmap Item 14 section 20: a weekly pattern summary. Needs
/// progression context to say anything specific, so under
/// [AiPrivacyLevel.limitedContext] this returns the deterministic
/// fallback directly rather than sending a request that would read as
/// generic (see [AiCoachContextBuilder.supports]).
class GetWeeklyRecapUseCase {
  GetWeeklyRecapUseCase(
    this._repository, {
    RequestIdGenerator? requestIdGenerator,
  }) : _requestIds =
           requestIdGenerator ?? SequentialRequestIdGenerator(prefix: 'ai-req');

  final AiCoachRepository _repository;
  final RequestIdGenerator _requestIds;

  Future<AiCoachResponse> call({
    required AiPrivacyLevel privacyLevel,
    required String displayName,
    required int activeDaysThisWeek,
    required String consistencySummary,
    required int currentLevel,
    required String currentTitle,
    String? currentLeagueName,
    List<String> recentCategoryUsage = const [],
    AiPersonalizationProfile personalization = const AiPersonalizationProfile(),
  }) {
    final context = AiCoachContextBuilder.build(
      privacyLevel: privacyLevel,
      displayName: displayName,
      activeDaysThisWeek: activeDaysThisWeek,
      consistencySummary: consistencySummary,
      currentLevel: currentLevel,
      currentTitle: currentTitle,
      currentLeagueName: currentLeagueName,
      recentCategoryUsage: recentCategoryUsage,
      personalization: personalization,
    );

    if (!AiCoachContextBuilder.supports(
      privacyLevel,
      needsProgressionContext: true,
    )) {
      return Future.value(
        AiCoachFallbackTemplates.forTask(AiCoachTask.weeklyRecap, context),
      );
    }

    return _repository.generate(
      AiCoachRequest(
        task: AiCoachTask.weeklyRecap,
        context: context,
        requestId: _requestIds.next(),
        contextVersion:
            '${activeDaysThisWeek}_${currentLevel}_$consistencySummary',
      ),
    );
  }
}
