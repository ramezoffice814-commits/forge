import '../../../../core/backend/request_id_generator.dart';
import '../entities/ai_coach_request.dart';
import '../entities/ai_coach_response.dart';
import '../entities/ai_personalization_profile.dart';
import '../enums/ai_coach_task.dart';
import '../enums/ai_privacy_level.dart';
import '../repositories/ai_coach_repository.dart';
import '../services/ai_coach_context_builder.dart';

/// Roadmap Item 14 sections 20 & 24: the minimal coach chat surface.
/// [userMessage] is the only free-text field this whole module ever
/// accepts from the user and forwards — never persisted beyond the
/// active chat session by anything in this use case (persistence, if
/// any, is a presentation-layer concern this class has no access to).
class SendCoachChatMessageUseCase {
  SendCoachChatMessageUseCase(
    this._repository, {
    RequestIdGenerator? requestIdGenerator,
  }) : _requestIds =
           requestIdGenerator ?? SequentialRequestIdGenerator(prefix: 'ai-req');

  final AiCoachRepository _repository;
  final RequestIdGenerator _requestIds;

  Future<AiCoachResponse> call({
    required AiPrivacyLevel privacyLevel,
    required String displayName,
    required String userMessage,
    AiPersonalizationProfile personalization = const AiPersonalizationProfile(),
  }) {
    final context = AiCoachContextBuilder.build(
      privacyLevel: privacyLevel,
      displayName: displayName,
      personalization: personalization,
      userMessage: userMessage,
    );

    // Never cached — each chat message is its own distinct exchange.
    return _repository.generate(
      AiCoachRequest(
        task: AiCoachTask.coachChat,
        context: context,
        requestId: _requestIds.next(),
      ),
    );
  }
}
