import '../../domain/entities/ai_coach_context.dart';
import '../../domain/entities/ai_coach_request.dart';
import '../../domain/entities/ai_coach_response.dart';
import '../../domain/enums/ai_coach_suggested_action.dart';
import '../../domain/enums/ai_coach_task.dart';
import '../../domain/enums/coaching_tone.dart';
import '../ai_coach_client.dart';

/// Deterministic mock provider (Roadmap Item 14 section 27) — same
/// input always produces the same output, no network, no randomness, no
/// clock dependency. This is the client every build uses today: no real
/// AI provider is configured (see the Item 14 final report's cost/
/// provider-selection section), and per spec section 3 mock mode "must
/// remain fully usable" regardless — this is that mode, not a stand-in
/// for it.
///
/// Deliberately produces genuinely templated-but-context-aware text
/// (reads [AiCoachContext] fields into the message) rather than one
/// static string per task, so callers/tests can tell personalization is
/// actually flowing through the pipeline, without ever claiming to be a
/// real generative response (spec section 3: "no fake claims that
/// remote AI was used" — this class's very existence as the mock is
/// itself the honest label; nothing in its output claims otherwise).
class MockAiCoachClient implements AiCoachClient {
  const MockAiCoachClient();

  @override
  Future<AiCoachResponse> generate(AiCoachRequest request) async {
    final context = request.context;
    final tonePrefix = switch (context.coachingTone) {
      CoachingTone.calm => '',
      CoachingTone.direct => 'Straight talk: ',
      CoachingTone.energetic => 'Let\'s go — ',
      CoachingTone.strategic => 'Here\'s the play: ',
    };

    final message = switch (request.task) {
      AiCoachTask.missionExplanation => _missionExplanation(
        context,
        tonePrefix,
      ),
      AiCoachTask.dailyTransmissionDialogue => _dailyTransmission(
        context,
        tonePrefix,
      ),
      AiCoachTask.postMissionCoaching => _postMission(context, tonePrefix),
      AiCoachTask.weeklyRecap => _weeklyRecap(context, tonePrefix),
      AiCoachTask.coachChat => _coachChat(context, tonePrefix),
    };

    final actions = switch (request.task) {
      AiCoachTask.missionExplanation => const [
        AiCoachSuggestedAction.explainMission,
      ],
      AiCoachTask.coachChat => const [
        AiCoachSuggestedAction.requestEasierMission,
        AiCoachSuggestedAction.openProgress,
      ],
      _ => const <AiCoachSuggestedAction>[],
    };

    return AiCoachResponse.tryParse({
      'message': message,
      'reasoningSummary':
          'Composed from today\'s mission and this week\'s consistency.',
      'suggestedActions': actions.map((a) => a.name).toList(),
    })!;
  }

  String _missionExplanation(AiCoachContext context, String tonePrefix) {
    final title = context.currentMissionTitle ?? 'today\'s mission';
    final minutes = context.availableMinutesToday;
    return '$tonePrefix$title fits the $minutes minutes you have today'
        '${context.isRecoveryMode ? ', kept light on purpose' : ''}. '
        'Start whenever you\'re ready — one clean effort is enough.';
  }

  String _dailyTransmission(AiCoachContext context, String tonePrefix) {
    return '${tonePrefix}The current runs strong again today, ${context.displayName}.';
  }

  String _postMission(AiCoachContext context, String tonePrefix) {
    return '${tonePrefix}Done — that\'s ${context.consistencySummary.isEmpty ? 'one more in the log' : context.consistencySummary}.';
  }

  String _weeklyRecap(AiCoachContext context, String tonePrefix) {
    return '$tonePrefix${context.activeDaysThisWeek} active day(s) this week. '
        'Steady effort, well logged.';
  }

  String _coachChat(AiCoachContext context, String tonePrefix) {
    final question = context.userMessage;
    if (question == null || question.isEmpty) {
      return '${tonePrefix}What would you like to know about today\'s mission or your progress?';
    }
    return '${tonePrefix}On "$question" — your current mission is '
        '${context.currentMissionTitle ?? 'still loading'}, and you\'re '
        'level ${context.currentLevel} right now.';
  }
}
