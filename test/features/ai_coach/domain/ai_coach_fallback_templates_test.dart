import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_context.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_coach_task.dart';
import 'package:forge/features/ai_coach/domain/enums/coaching_tone.dart';
import 'package:forge/features/ai_coach/domain/services/ai_coach_fallback_templates.dart';

void main() {
  const context = AiCoachContext(
    displayName: 'Alex',
    currentMissionTitle: null,
    currentMissionCategory: null,
    currentMissionDifficulty: null,
    availableMinutesToday: 20,
    recentCompletionRatePercent: 0,
    activeDaysThisWeek: 0,
    currentLevel: 1,
    currentTitle: '',
    currentLeagueName: null,
    recentCategoryUsage: [],
    consistencySummary: '',
    isRecoveryMode: false,
    preferredCategories: [],
    dislikedCategories: [],
    goalFocusLabel: null,
    coachingTone: CoachingTone.calm,
  );

  test('produces a non-empty message for every task, never throwing', () {
    for (final task in AiCoachTask.values) {
      final response = AiCoachFallbackTemplates.forTask(task, context);
      expect(response.message, isNotEmpty);
    }
  });

  test('fallback responses never carry a reasoningSummary', () {
    final response = AiCoachFallbackTemplates.forTask(
      AiCoachTask.weeklyRecap,
      context,
    );
    expect(response.reasoningSummary, isNull);
  });
}
