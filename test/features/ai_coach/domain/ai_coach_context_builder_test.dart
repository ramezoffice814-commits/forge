import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_personalization_profile.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_privacy_level.dart';
import 'package:forge/features/ai_coach/domain/services/ai_coach_context_builder.dart';

void main() {
  test('fullContext preserves progression/behavioral fields as given', () {
    final context = AiCoachContextBuilder.build(
      privacyLevel: AiPrivacyLevel.fullContext,
      displayName: 'Alex',
      activeDaysThisWeek: 5,
      currentLevel: 12,
      currentTitle: 'Disciplined',
      consistencySummary: 'steady this week',
      recentCategoryUsage: ['fitness'],
    );

    expect(context.activeDaysThisWeek, 5);
    expect(context.currentLevel, 12);
    expect(context.currentTitle, 'Disciplined');
    expect(context.consistencySummary, 'steady this week');
    expect(context.recentCategoryUsage, ['fitness']);
  });

  test(
    'limitedContext zeroes progression/behavioral fields, not merely hides them',
    () {
      final context = AiCoachContextBuilder.build(
        privacyLevel: AiPrivacyLevel.limitedContext,
        displayName: 'Alex',
        activeDaysThisWeek: 5,
        recentCompletionRatePercent: 90,
        currentLevel: 12,
        currentTitle: 'Disciplined',
        currentLeagueName: 'Gold',
        consistencySummary: 'steady this week',
        recentCategoryUsage: ['fitness'],
      );

      expect(context.activeDaysThisWeek, 0);
      expect(context.recentCompletionRatePercent, 0);
      expect(context.currentLevel, 1);
      expect(context.currentTitle, '');
      expect(context.currentLeagueName, isNull);
      expect(context.consistencySummary, '');
      expect(context.recentCategoryUsage, isEmpty);
    },
  );

  test('limitedContext still carries the current mission fields', () {
    final context = AiCoachContextBuilder.build(
      privacyLevel: AiPrivacyLevel.limitedContext,
      displayName: 'Alex',
      currentMissionTitle: 'Morning run',
      currentMissionCategory: 'fitness',
    );
    expect(context.currentMissionTitle, 'Morning run');
    expect(context.currentMissionCategory, 'fitness');
  });

  test('personalization fields flow through unconditionally', () {
    const profile = AiPersonalizationProfile(preferredCategories: ['fitness']);
    final context = AiCoachContextBuilder.build(
      privacyLevel: AiPrivacyLevel.limitedContext,
      displayName: 'Alex',
      personalization: profile,
    );
    expect(context.preferredCategories, ['fitness']);
    expect(context.coachingTone, profile.coachingTone);
  });

  test('userMessage longer than the cap is truncated, not rejected', () {
    final longMessage = 'a' * 600;
    final context = AiCoachContextBuilder.build(
      privacyLevel: AiPrivacyLevel.fullContext,
      displayName: 'Alex',
      userMessage: longMessage,
    );
    expect(context.userMessage!.length, 500);
  });

  test('supports() is false for disabled regardless of task', () {
    expect(
      AiCoachContextBuilder.supports(
        AiPrivacyLevel.disabled,
        needsProgressionContext: false,
      ),
      isFalse,
    );
  });

  test(
    'supports() is false for limitedContext when progression context is needed',
    () {
      expect(
        AiCoachContextBuilder.supports(
          AiPrivacyLevel.limitedContext,
          needsProgressionContext: true,
        ),
        isFalse,
      );
    },
  );

  test(
    'supports() is true for limitedContext when progression context is not needed',
    () {
      expect(
        AiCoachContextBuilder.supports(
          AiPrivacyLevel.limitedContext,
          needsProgressionContext: false,
        ),
        isTrue,
      );
    },
  );

  test('supports() is true for fullContext regardless of task', () {
    expect(
      AiCoachContextBuilder.supports(
        AiPrivacyLevel.fullContext,
        needsProgressionContext: true,
      ),
      isTrue,
    );
  });
}
