import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/ai_coach/data/ai_coach_cache_store.dart';
import 'package:forge/features/ai_coach/data/ai_coach_client.dart';
import 'package:forge/features/ai_coach/data/ai_coach_repository_impl.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_context.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_request.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_response.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_coach_task.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_privacy_level.dart';
import 'package:forge/features/ai_coach/domain/enums/coaching_tone.dart';
import 'package:forge/features/ai_coach/domain/failures/ai_coach_failure.dart';
import 'package:forge/features/ai_coach/domain/services/ai_coach_rate_limiter.dart';

import '../../../support/fake_secure_key_value_store.dart';

class _StubAiCoachClient implements AiCoachClient {
  _StubAiCoachClient(this._respond);

  final Future<AiCoachResponse> Function(AiCoachRequest request) _respond;
  int callCount = 0;

  @override
  Future<AiCoachResponse> generate(AiCoachRequest request) {
    callCount++;
    return _respond(request);
  }
}

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

  AiCoachCacheStore fakeCacheStore() =>
      AiCoachCacheStore(FakeSecureKeyValueStore());

  test(
    'returns the deterministic fallback without calling the client when disabled',
    () async {
      final client = _StubAiCoachClient(
        (_) async => throw StateError('must not be called'),
      );
      final repository = AiCoachRepositoryImpl(
        client: client,
        cacheStore: fakeCacheStore(),
        privacyLevel: () => AiPrivacyLevel.disabled,
      );

      final response = await repository.generate(
        AiCoachRequest(
          task: AiCoachTask.coachChat,
          context: context,
          requestId: 'req-1',
        ),
      );

      expect(client.callCount, 0);
      expect(response.message, isNotEmpty);
    },
  );

  test(
    'returns the real response on success and caches it when cacheable',
    () async {
      final client = _StubAiCoachClient(
        (_) async => AiCoachResponse.local('real response'),
      );
      final cacheStore = fakeCacheStore();
      final repository = AiCoachRepositoryImpl(
        client: client,
        cacheStore: cacheStore,
        privacyLevel: () => AiPrivacyLevel.fullContext,
      );

      final response = await repository.generate(
        AiCoachRequest(
          task: AiCoachTask.missionExplanation,
          context: context,
          requestId: 'req-1',
          contextVersion: 'v1',
        ),
      );

      expect(response.message, 'real response');
      expect(client.callCount, 1);

      final cached = await cacheStore.load(
        AiCoachTask.missionExplanation,
        'v1',
      );
      expect(cached, isNotNull);
      expect(cached!.message, 'real response');
    },
  );

  test('serves a cached response without calling the client again', () async {
    final client = _StubAiCoachClient(
      (_) async => AiCoachResponse.local('first call'),
    );
    final cacheStore = fakeCacheStore();
    final repository = AiCoachRepositoryImpl(
      client: client,
      cacheStore: cacheStore,
      privacyLevel: () => AiPrivacyLevel.fullContext,
    );

    final request = AiCoachRequest(
      task: AiCoachTask.weeklyRecap,
      context: context,
      requestId: 'req-1',
      contextVersion: 'v1',
    );

    await repository.generate(request);
    final second = await repository.generate(
      AiCoachRequest(
        task: AiCoachTask.weeklyRecap,
        context: context,
        requestId: 'req-2',
        contextVersion: 'v1',
      ),
    );

    expect(client.callCount, 1);
    expect(second.message, 'first call');
  });

  test('falls back when the client throws AiCoachFailure', () async {
    final client = _StubAiCoachClient(
      (_) async =>
          throw const AiCoachFailure(AiCoachFailureReason.providerError),
    );
    final repository = AiCoachRepositoryImpl(
      client: client,
      cacheStore: fakeCacheStore(),
      privacyLevel: () => AiPrivacyLevel.fullContext,
    );

    final response = await repository.generate(
      AiCoachRequest(
        task: AiCoachTask.coachChat,
        context: context,
        requestId: 'req-1',
      ),
    );

    expect(response.message, isNotEmpty);
  });

  test('falls back when the client times out', () async {
    final client = _StubAiCoachClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return AiCoachResponse.local('too slow');
    });
    final repository = AiCoachRepositoryImpl(
      client: client,
      cacheStore: fakeCacheStore(),
      privacyLevel: () => AiPrivacyLevel.fullContext,
      timeout: const Duration(milliseconds: 5),
    );

    final response = await repository.generate(
      AiCoachRequest(
        task: AiCoachTask.coachChat,
        context: context,
        requestId: 'req-1',
      ),
    );

    expect(response.message, isNot('too slow'));
  });

  test(
    'falls back when the response is flagged unsafe, never caching it',
    () async {
      final client = _StubAiCoachClient(
        (_) async => AiCoachResponse.local('your xp has been increased'),
      );
      final cacheStore = fakeCacheStore();
      final repository = AiCoachRepositoryImpl(
        client: client,
        cacheStore: cacheStore,
        privacyLevel: () => AiPrivacyLevel.fullContext,
      );

      final response = await repository.generate(
        AiCoachRequest(
          task: AiCoachTask.missionExplanation,
          context: context,
          requestId: 'req-1',
          contextVersion: 'v1',
        ),
      );

      expect(response.message, isNot(contains('xp has been')));
      final cached = await cacheStore.load(
        AiCoachTask.missionExplanation,
        'v1',
      );
      expect(cached, isNull);
    },
  );

  test(
    'falls back once the rate limiter is exhausted, without calling the client',
    () async {
      final client = _StubAiCoachClient(
        (_) async => AiCoachResponse.local('real response'),
      );
      final repository = AiCoachRepositoryImpl(
        client: client,
        cacheStore: fakeCacheStore(),
        privacyLevel: () => AiPrivacyLevel.fullContext,
        rateLimiter: AiCoachRateLimiter(maxRequestsPerWindow: 1),
      );

      await repository.generate(
        AiCoachRequest(
          task: AiCoachTask.coachChat,
          context: context,
          requestId: 'req-1',
        ),
      );
      final second = await repository.generate(
        AiCoachRequest(
          task: AiCoachTask.coachChat,
          context: context,
          requestId: 'req-2',
        ),
      );

      expect(client.callCount, 1);
      expect(second.message, isNotEmpty);
    },
  );
}
