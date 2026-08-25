import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/features/ai_coach/data/ai_coach_client.dart';
import 'package:forge/features/ai_coach/data/ai_privacy_preference_store.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_context.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_request.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_response.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_coach_task.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_privacy_level.dart';
import 'package:forge/features/ai_coach/domain/enums/coaching_tone.dart';
import 'package:forge/features/ai_coach/presentation/providers/ai_coach_providers.dart';

import '../../../support/fake_secure_key_value_store.dart';

class _CountingClient implements AiCoachClient {
  int callCount = 0;

  @override
  Future<AiCoachResponse> generate(AiCoachRequest request) async {
    callCount++;
    return AiCoachResponse.local('should never be reached when disabled');
  }
}

void main() {
  test(
    'a restart (fresh ProviderContainer over the same storage) restores '
    'a previously saved privacy level via aiPrivacyBootstrapProvider',
    () async {
      final backingStore = FakeSecureKeyValueStore();

      // First "session": user picks fullContext and it gets persisted.
      final first = ProviderContainer(
        overrides: [
          secureKeyValueStoreProvider.overrideWithValue(backingStore),
        ],
      );
      addTearDown(first.dispose);
      first.read(aiPrivacyLevelProvider.notifier).state =
          AiPrivacyLevel.fullContext;
      await first
          .read(aiPrivacyPreferenceStoreProvider)
          .save(AiPrivacyLevel.fullContext);
      expect(first.read(aiPrivacyLevelProvider), AiPrivacyLevel.fullContext);

      // Second "session": a brand-new container, defaults to
      // limitedContext until the bootstrap provider resolves — exactly
      // like a real app restart.
      final second = ProviderContainer(
        overrides: [
          secureKeyValueStoreProvider.overrideWithValue(backingStore),
        ],
      );
      addTearDown(second.dispose);
      expect(
        second.read(aiPrivacyLevelProvider),
        AiPrivacyLevel.limitedContext,
      );

      await second.read(aiPrivacyBootstrapProvider.future);
      expect(second.read(aiPrivacyLevelProvider), AiPrivacyLevel.fullContext);
    },
  );

  test('AI disabled sends zero requests to the client, even across a '
      'restart that restores the disabled choice', () async {
    final backingStore = FakeSecureKeyValueStore();
    await AiPrivacyPreferenceStore(backingStore).save(AiPrivacyLevel.disabled);

    final client = _CountingClient();
    final container = ProviderContainer(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(backingStore),
        aiCoachClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    await container.read(aiPrivacyBootstrapProvider.future);
    expect(container.read(aiPrivacyLevelProvider), AiPrivacyLevel.disabled);

    final repository = container.read(aiCoachRepositoryProvider);
    final response = await repository.generate(
      const AiCoachRequest(
        task: AiCoachTask.coachChat,
        context: AiCoachContext(
          displayName: 'Alex',
          currentMissionTitle: null,
          currentMissionCategory: null,
          currentMissionDifficulty: null,
          availableMinutesToday: 20,
          recentCompletionRatePercent: 0,
          activeDaysThisWeek: 0,
          currentLevel: 1,
          currentTitle: 'Novice',
          currentLeagueName: null,
          recentCategoryUsage: [],
          consistencySummary: '',
          isRecoveryMode: false,
          preferredCategories: [],
          dislikedCategories: [],
          goalFocusLabel: null,
          coachingTone: CoachingTone.calm,
        ),
        requestId: 'req-1',
      ),
    );

    expect(response.message, isNotEmpty);
    expect(
      client.callCount,
      0,
      reason: 'AiPrivacyLevel.disabled must never reach the AI client',
    );
  });
}
