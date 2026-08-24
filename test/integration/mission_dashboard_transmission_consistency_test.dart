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
import 'package:forge/features/missions/presentation/providers/resolved_mission_instance_controller.dart';
import 'package:forge/features/missions/presentation/widgets/mission_explanation_panel.dart';
import 'package:forge/shared/widgets/forge_button.dart';

import '../support/fake_auth_overrides.dart';
import '../support/fake_secure_key_value_store.dart';
import '../support/fast_transmission_repository.dart';

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
}
