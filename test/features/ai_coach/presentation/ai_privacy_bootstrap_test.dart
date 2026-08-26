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
import 'package:forge/features/auth/domain/entities/auth_session.dart';
import 'package:forge/features/auth/domain/entities/auth_user.dart';
import 'package:forge/features/auth/presentation/auth_state.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';

import '../../../support/fake_auth_overrides.dart';
import '../../../support/fake_secure_key_value_store.dart';

class _CountingClient implements AiCoachClient {
  int callCount = 0;

  @override
  Future<AiCoachResponse> generate(AiCoachRequest request) async {
    callCount++;
    return AiCoachResponse.local('should never be reached when disabled');
  }
}

/// An authenticated session for an arbitrary [userId] — [testAuthSession]
/// (from `fake_auth_overrides.dart`) always hardcodes `'test-user'`,
/// which isn't enough to test two genuinely different accounts.
class _FixedUserAuthNotifier extends AuthStateNotifier {
  _FixedUserAuthNotifier(this.userId);
  final String userId;

  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      session: AuthSession(
        user: AuthUser(
          id: userId,
          displayName: userId,
          email: '$userId@forge.test',
          createdAt: DateTime.utc(2026, 1, 1),
          onboardingCompleted: true,
        ),
        accessToken: 'token-$userId',
      ),
    );
  }
}

AuthSession _sessionFor(String userId) => AuthSession(
  user: AuthUser(
    id: userId,
    displayName: userId,
    email: '$userId@forge.test',
    createdAt: DateTime.utc(2026, 1, 1),
    onboardingCompleted: true,
  ),
  accessToken: 'token-$userId',
);

/// A single notifier instance whose state is mutated directly via its
/// own `state` setter — the standard, reliably-reactive way to simulate
/// a sequence of auth transitions (sign in as A, sign out, sign in as
/// B) within one continuous session, unlike swapping which override a
/// provider uses mid-test.
class _ControllableAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);

  void signInAs(String userId) {
    state = AuthState(
      status: AuthStatus.authenticated,
      session: _sessionFor(userId),
    );
  }

  @override
  Future<void> signOut() async {
    state = const AuthState(status: AuthStatus.unauthenticated);
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
          authStateNotifierProvider.overrideWith(
            () => _FixedUserAuthNotifier('user-a'),
          ),
        ],
      );
      addTearDown(first.dispose);
      await first.read(aiPrivacyBootstrapProvider.future);
      first.read(aiPrivacyLevelProvider.notifier).state =
          AiPrivacyLevel.fullContext;
      await first
          .read(aiPrivacyPreferenceStoreProvider)
          .save('user-a', AiPrivacyLevel.fullContext);
      expect(first.read(aiPrivacyLevelProvider), AiPrivacyLevel.fullContext);

      // Second "session": a brand-new container, same user, defaults to
      // limitedContext until the bootstrap provider resolves — exactly
      // like a real app restart.
      final second = ProviderContainer(
        overrides: [
          secureKeyValueStoreProvider.overrideWithValue(backingStore),
          authStateNotifierProvider.overrideWith(
            () => _FixedUserAuthNotifier('user-a'),
          ),
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
    await AiPrivacyPreferenceStore(
      backingStore,
    ).save('user-a', AiPrivacyLevel.disabled);

    final client = _CountingClient();
    final container = ProviderContainer(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(backingStore),
        authStateNotifierProvider.overrideWith(
          () => _FixedUserAuthNotifier('user-a'),
        ),
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

  test('Roadmap Item 16 account-switch audit: signing out resets AI privacy '
      'to the safe default, and a different user signing in on the same '
      'device never inherits the previous user\'s choice', () async {
    final backingStore = FakeSecureKeyValueStore();
    await AiPrivacyPreferenceStore(
      backingStore,
    ).save('user-a', AiPrivacyLevel.fullContext);

    final authNotifier = _ControllableAuthNotifier();
    final container = ProviderContainer(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(backingStore),
        authStateNotifierProvider.overrideWith(() => authNotifier),
      ],
    );
    addTearDown(container.dispose);

    // Force Riverpod to actually build the notifier (attaching its
    // element) before driving it directly — the `state` setter throws
    // `LateInitializationError` until then.
    container.read(authStateNotifierProvider);

    authNotifier.signInAs('user-a');
    await container.read(aiPrivacyBootstrapProvider.future);
    expect(container.read(aiPrivacyLevelProvider), AiPrivacyLevel.fullContext);

    // user-a signs out.
    authNotifier.signOut();
    await container.read(aiPrivacyBootstrapProvider.future);
    expect(
      container.read(aiPrivacyLevelProvider),
      AiPrivacyLevel.limitedContext,
      reason: 'signing out must reset the in-memory level to the safe default',
    );

    // user-b signs in on the same running app — never saved anything.
    authNotifier.signInAs('user-b');
    await container.read(aiPrivacyBootstrapProvider.future);
    expect(
      container.read(aiPrivacyLevelProvider),
      AiPrivacyLevel.limitedContext,
      reason: 'user-b must never inherit user-a\'s persisted choice',
    );
  });
}
