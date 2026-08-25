import '../../../../core/backend/request_id_generator.dart';
import '../entities/ai_coach_request.dart';
import '../entities/ai_coach_response.dart';
import '../entities/ai_personalization_profile.dart';
import '../enums/ai_coach_task.dart';
import '../enums/ai_privacy_level.dart';
import '../repositories/ai_coach_repository.dart';
import '../services/ai_coach_context_builder.dart';

/// Roadmap Item 14 section 20: an additive opening/closing line for the
/// Daily Transmission — never replaces the existing deterministic mock
/// script, only supplements it (see the presentation-layer wiring).
class GetDailyTransmissionDialogueUseCase {
  GetDailyTransmissionDialogueUseCase(
    this._repository, {
    RequestIdGenerator? requestIdGenerator,
  }) : _requestIds =
           requestIdGenerator ?? SequentialRequestIdGenerator(prefix: 'ai-req');

  final AiCoachRepository _repository;
  final RequestIdGenerator _requestIds;

  Future<AiCoachResponse> call({
    required AiPrivacyLevel privacyLevel,
    required String displayName,
    required bool isRecoveryMode,
    int activeDaysThisWeek = 0,
    String consistencySummary = '',
    AiPersonalizationProfile personalization = const AiPersonalizationProfile(),
  }) {
    final context = AiCoachContextBuilder.build(
      privacyLevel: privacyLevel,
      displayName: displayName,
      isRecoveryMode: isRecoveryMode,
      activeDaysThisWeek: activeDaysThisWeek,
      consistencySummary: consistencySummary,
      personalization: personalization,
    );

    return _repository.generate(
      AiCoachRequest(
        task: AiCoachTask.dailyTransmissionDialogue,
        context: context,
        requestId: _requestIds.next(),
        contextVersion:
            '${consistencySummary}_${isRecoveryMode}_${privacyLevel.name}',
      ),
    );
  }
}
