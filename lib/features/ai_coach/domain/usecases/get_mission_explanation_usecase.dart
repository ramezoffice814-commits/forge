import '../../../../core/backend/request_id_generator.dart';
import '../entities/ai_coach_request.dart';
import '../entities/ai_coach_response.dart';
import '../entities/ai_personalization_profile.dart';
import '../enums/ai_coach_task.dart';
import '../enums/ai_privacy_level.dart';
import '../repositories/ai_coach_repository.dart';
import '../services/ai_coach_context_builder.dart';

/// Roadmap Item 14 section 20: "why was I given this mission" — the
/// caller supplies only already-public mission fields (title/category/
/// difficulty), never a raw `MissionAggregate`.
class GetMissionExplanationUseCase {
  GetMissionExplanationUseCase(
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
    required String missionDifficulty,
    int availableMinutesToday = 20,
    AiPersonalizationProfile personalization = const AiPersonalizationProfile(),
  }) {
    final context = AiCoachContextBuilder.build(
      privacyLevel: privacyLevel,
      displayName: displayName,
      currentMissionTitle: missionTitle,
      currentMissionCategory: missionCategory,
      currentMissionDifficulty: missionDifficulty,
      availableMinutesToday: availableMinutesToday,
      personalization: personalization,
    );

    return _repository.generate(
      AiCoachRequest(
        task: AiCoachTask.missionExplanation,
        context: context,
        requestId: _requestIds.next(),
        contextVersion: '${missionTitle}_${privacyLevel.name}',
      ),
    );
  }
}
