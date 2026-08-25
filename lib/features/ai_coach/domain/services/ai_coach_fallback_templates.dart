import '../entities/ai_coach_context.dart';
import '../entities/ai_coach_response.dart';
import '../enums/ai_coach_task.dart';

/// Deterministic, always-available copy for every [AiCoachTask] (Roadmap
/// Item 14 section 14) — used whenever AI is disabled, offline, timed
/// out, rate-limited, or returned something unsafe/malformed. Never a
/// network call, never provider-dependent, so this can never itself be
/// the reason a screen fails to render. Every string here was reviewed
/// against `CharacterPersona.watcher.forbiddenBehaviors` by construction
/// (no shaming, no urgency, no authority claims) — this is the copy the
/// safety filter is implicitly comparing generated output against.
abstract final class AiCoachFallbackTemplates {
  static AiCoachResponse forTask(AiCoachTask task, AiCoachContext context) {
    return switch (task) {
      AiCoachTask.missionExplanation => AiCoachResponse.local(
        context.currentMissionTitle == null
            ? 'A mission is being prepared for you.'
            : 'Today: ${context.currentMissionTitle}. '
                  'One focused effort, at your own pace.',
      ),
      AiCoachTask.dailyTransmissionDialogue => AiCoachResponse.local(
        'Another day, another chance to show up.',
      ),
      AiCoachTask.postMissionCoaching => AiCoachResponse.local(
        'Done. That counts.',
      ),
      AiCoachTask.weeklyRecap => AiCoachResponse.local(
        'This week is in the books — steady effort adds up.',
      ),
      AiCoachTask.coachChat => AiCoachResponse.local(
        "I can't reach the coaching service right now, but your "
        "mission and progress are exactly where you left them.",
      ),
    };
  }
}
