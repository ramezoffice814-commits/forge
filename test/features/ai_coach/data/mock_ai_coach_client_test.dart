import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/ai_coach/data/mock/mock_ai_coach_client.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_context.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_request.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_coach_task.dart';
import 'package:forge/features/ai_coach/domain/enums/coaching_tone.dart';

void main() {
  const context = AiCoachContext(
    displayName: 'Alex',
    currentMissionTitle: 'Morning run',
    currentMissionCategory: 'fitness',
    currentMissionDifficulty: 'medium',
    availableMinutesToday: 30,
    recentCompletionRatePercent: 80,
    activeDaysThisWeek: 5,
    currentLevel: 8,
    currentTitle: 'Disciplined',
    currentLeagueName: 'Silver',
    recentCategoryUsage: ['fitness'],
    consistencySummary: 'steady this week',
    isRecoveryMode: false,
    preferredCategories: ['fitness'],
    dislikedCategories: [],
    goalFocusLabel: 'consistency',
    coachingTone: CoachingTone.calm,
  );

  const client = MockAiCoachClient();

  test('is deterministic for the same request', () async {
    final request = AiCoachRequest(
      task: AiCoachTask.missionExplanation,
      context: context,
      requestId: 'req-1',
    );
    final first = await client.generate(request);
    final second = await client.generate(request);
    expect(first.message, second.message);
  });

  test('produces a non-empty response for every task', () async {
    for (final task in AiCoachTask.values) {
      final response = await client.generate(
        AiCoachRequest(task: task, context: context, requestId: 'req-$task'),
      );
      expect(response.message, isNotEmpty);
    }
  });

  test('never performs network I/O — resolves synchronously fast', () async {
    final stopwatch = Stopwatch()..start();
    await client.generate(
      AiCoachRequest(
        task: AiCoachTask.coachChat,
        context: context,
        requestId: 'req-1',
      ),
    );
    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, lessThan(50));
  });
}
