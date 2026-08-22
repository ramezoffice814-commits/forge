import '../../../../core/backend/request_id_generator.dart';
import '../entities/ai_coach_request.dart';
import '../entities/ai_coach_response.dart';
import '../entities/ai_personalization_profile.dart';
import '../enums/ai_coach_task.dart';
import '../enums/ai_privacy_level.dart';
import '../repositories/ai_coach_repository.dart';
import '../services/ai_coach_context_builder.dart';

/// Roadmap Item 14 section 20: a brief reflection shown after a mission
/// completes. The mission is already server-confirmed complete by the
/// time this is called — this use case only asks for a coaching remark
/// about it, never anything that could affect the completion itself.
class GetPostMissionCoachingUseCase {
  GetPostMissionCoachingUseCase(
    this._repository, {
    RequestIdGenerator? requestIdGenerator,
  }) : _requestIds =
           requestIdGenerator ?? SequentialRequestIdGenerator(prefix: 'ai-req');

  final AiCoachRepository _repository;
  final RequestIdGenerator _requestIds;

  Future<AiCoachResponse> call({
    required AiPrivacyLevel privacyLevel,
    required String displayName,
    required String missionTitle,
    required String missionCategory,
    String consistencySummary = '',
    AiPersonalizationProfile personalization = const AiPersonalizationProfile(),
  }) {
    final context = AiCoachContextBuilder.build(
      privacyLevel: privacyLevel,
      displayName: displayName,
      currentMissionTitle: missionTitle,
      currentMissionCategory: missionCategory,
      consistencySummary: consistencySummary,
      personalization: personalization,
    );

    // Never cached — a completion just happened, so a stale cached
    // remark from an earlier completion would read as wrong every time.
    return _repository.generate(
      AiCoachRequest(
        task: AiCoachTask.postMissionCoaching,
        context: context,
        requestId: _requestIds.next(),
      ),
    );
  }
}
