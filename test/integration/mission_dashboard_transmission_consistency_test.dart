// Verifies the core architectural promise of this phase: Dashboard and the
// Daily Transmission experience present the *same* MissionInstance, never
// two independently-authored copies of "today's mission". The expected
// title is deterministic (see mission_selection_engine_test.dart's sibling
// probe) — normalActive's mock profile/history/catalog combination always
// resolves to the same mission.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/app.dart';
import 'package:forge/core/backend/backend_mode.dart';
import 'package:forge/core/backend/backend_providers.dart';
import 'package:forge/core/backend/mission_assignment_client.dart';
import 'package:forge/core/router/app_router.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/character/data/mock/fake_character_animation_controller.dart';
import 'package:forge/features/character/data/mock/fake_tts_service.dart';
import 'package:forge/features/character/data/transmission_repository_provider.dart';
import 'package:forge/features/character/presentation/controllers/daily_transmission_controller.dart';
import 'package:forge/features/character/presentation/daily_transmission_page.dart';
import 'package:forge/features/character/data/tts_service_provider.dart';
import 'package:forge/features/ai_coach/data/ai_coach_client.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_request.dart';
import 'package:forge/features/ai_coach/domain/entities/ai_coach_response.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_privacy_level.dart';
import 'package:forge/features/ai_coach/presentation/providers/ai_coach_providers.dart';
import 'package:forge/features/ai_coach/presentation/providers/mission_ai_insight_provider.dart';
import 'package:forge/features/missions/presentation/providers/resolved_mission_instance_controller.dart';
import 'package:forge/features/missions/presentation/widgets/mission_explanation_panel.dart';
import 'package:forge/shared/widgets/forge_button.dart';

import '../support/fake_auth_overrides.dart';
import '../support/fake_secure_key_value_store.dart';
import '../support/fast_transmission_repository.dart';

class _CapturingAiCoachClient implements AiCoachClient {
  AiCoachRequest? lastRequest;

  @override
  Future<AiCoachResponse> generate(AiCoachRequest request) async {
    lastRequest = request;
    return AiCoachResponse.local('captured');
  }
}

class _FakeLiveAssignmentClient implements MissionAssignmentClient {
  int callCount = 0;

  @override
  Future<MissionAssignmentResult> assignDailyMission({
    required String commandId,
    required String idempotencyKey,
    String? requestedMissionDefinitionId,
    String? requestedCategory,
  }) async {
    callCount++;
    return MissionAssignmentResult(
      missionInstanceId: 'server-assigned-instance-13c',
      missionDefinitionId: 'fit-stretch-10',
      assignedDate: DateTime.utc(2026, 1, 1),
      serverTimestamp: DateTime.utc(2026, 1, 1),
      confirmationId: 'conf-13c',
    );
  }
}

void main() {
  const expectedTitle = '10-Minute Full-Body Stretch';

  testWidgets('the mission title shown on Dashboard is the exact same title '
      'announced by the Daily Transmission experience', (tester) async {
    final tts = FakeTtsService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureKeyValueStoreProvider.overrideWithValue(
            FakeSecureKeyValueStore(),
          ),
          authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
          ttsServiceProvider.overrideWithValue(tts),
          characterAnimationControllerFactoryProvider.overrideWithValue(
            FakeCharacterAnimationController.new,
          ),
          transmissionRepositoryProvider.overrideWithValue(
            fastMockTransmissionRepository(
              TransmissionMockScenario.normalActive,
            ),
          ),
        ],
        child: const ForgeApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Dashboard shows the engine-selected mission, with its explanation
    // panel available (proof the engine, not a hardcoded literal, is the
    // source).
    expect(find.text(expectedTitle), findsOneWidget);
    expect(find.byType(MissionExplanationPanel), findsOneWidget);

    final viewMissionButton = find.widgetWithText(ForgeButton, 'View Mission');
    await tester.ensureVisible(viewMissionButton);
    await tester.pumpAndSettle();
    await tester.tap(viewMissionButton);
    await tester.pumpAndSettle();

    // Skip straight to the mission reveal in the transmission experience.
    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(DailyTransmissionPage), findsOneWidget);
    expect(find.text("TODAY'S MISSION"), findsOneWidget);
    expect(find.text(expectedTitle), findsOneWidget);
  });

  testWidgets('live mode: Dashboard and Daily Transmission both show the '
      'server-assigned mission, and only one assignment request is ever '
      'made (Roadmap Item 13C)', (tester) async {
    final tts = FakeTtsService();
    final assignmentClient = _FakeLiveAssignmentClient();

    final container = ProviderContainer(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
        authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
        ttsServiceProvider.overrideWithValue(tts),
        characterAnimationControllerFactoryProvider.overrideWithValue(
          FakeCharacterAnimationController.new,
        ),
        transmissionRepositoryProvider.overrideWithValue(
          fastMockTransmissionRepository(TransmissionMockScenario.normalActive),
        ),
        backendModeProvider.overrideWithValue(BackendMode.liveSupabase),
        currentBackendUserIdProvider.overrideWithValue(testAuthSession.user.id),
        missionAssignmentClientProvider.overrideWithValue(assignmentClient),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: ForgeTheme.dark(),
          routerConfig: container.read(appRouterProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(expectedTitle), findsOneWidget);

    final resolved = container.read(resolvedMissionInstanceProvider);
    expect(resolved, isNotNull);
    expect(resolved!.instance.instanceId, 'server-assigned-instance-13c');

    final viewMissionButton = find.widgetWithText(ForgeButton, 'View Mission');
    await tester.ensureVisible(viewMissionButton);
    await tester.pumpAndSettle();
    await tester.tap(viewMissionButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(DailyTransmissionPage), findsOneWidget);
    expect(find.text(expectedTitle), findsOneWidget);

    // Accepting must dispatch lifecycle commands keyed by the exact
    // same server id Dashboard already showed — not a fresh local one.
    await tester.tap(find.widgetWithText(ForgeButton, 'Accept Mission'));
    await tester.pumpAndSettle();

    expect(
      assignmentClient.callCount,
      1,
      reason:
          'Dashboard and Transmission must share one resolution, '
          'never each requesting their own assignment',
    );
    expect(
      container.read(resolvedMissionInstanceProvider)!.instance.instanceId,
      'server-assigned-instance-13c',
      reason:
          'the resolved id must still be the server id after '
          'accepting — never regenerated mid-flow',
    );
  });

  // Plain `test`, not `testWidgets`: no widget tree is ever pumped here,
  // only Riverpod providers — using `testWidgets` needlessly would also
  // fail this test on the "no pending timers at teardown" invariant
  // `flutter_test` enforces for widget tests, tripped by the AI
  // repository's own internal request timeout timer even though it
  // resolves and is cancelled well before that invariant is checked.
  test(
    'AI Coach mission explanation request carries the exact same mission '
    'facts as the authoritative resolved instance (Roadmap Item 14B)',
    () async {
      final tts = FakeTtsService();
      final aiClient = _CapturingAiCoachClient();

      final container = ProviderContainer(
        overrides: [
          secureKeyValueStoreProvider.overrideWithValue(
            FakeSecureKeyValueStore(),
          ),
          authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
          ttsServiceProvider.overrideWithValue(tts),
          characterAnimationControllerFactoryProvider.overrideWithValue(
            FakeCharacterAnimationController.new,
          ),
          transmissionRepositoryProvider.overrideWithValue(
            fastMockTransmissionRepository(
              TransmissionMockScenario.normalActive,
            ),
          ),
          aiCoachClientProvider.overrideWithValue(aiClient),
          aiPrivacyLevelProvider.overrideWith(
            (ref) => AiPrivacyLevel.fullContext,
          ),
        ],
      );
      addTearDown(container.dispose);

      // Reading resolvedMissionInstanceProvider first, exactly like the
      // Dashboard/Transmission tests above, so this asserts against the
      // one authoritative source rather than a second, independently
      // constructed expectation.
      final ready = container.read(
        resolvedMissionInstanceControllerProvider.notifier,
      );
      await ready.ready;
      final resolved = container.read(resolvedMissionInstanceProvider)!;

      final response = await container.read(
        missionAiInsightProvider('Test User').future,
      );
      expect(response, isNotNull);

      final captured = aiClient.lastRequest;
      expect(captured, isNotNull);
      expect(captured!.context.currentMissionTitle, resolved.instance.title);
      expect(
        captured.context.currentMissionCategory,
        resolved.instance.category.name,
      );
      expect(
        captured.context.currentMissionDifficulty,
        resolved.instance.resolvedDifficulty.name,
      );
      expect(
        captured.context.currentMissionTitle,
        expectedTitle,
        reason:
            'sanity check against the same deterministic title the '
            'Dashboard/Transmission tests above assert on',
      );
    },
  );
}
