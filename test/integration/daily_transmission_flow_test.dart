// Integration coverage for the Daily Transmission experience, run under
// plain `flutter test` against the real app/router (see
// `auth_onboarding_flow_test.dart` for why this repo takes that approach
// instead of device-based `integration_test`).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/app.dart';
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
import 'package:forge/shared/widgets/forge_button.dart';

import '../support/fake_auth_overrides.dart';
import '../support/fake_secure_key_value_store.dart';
import '../support/fast_transmission_repository.dart';

void main() {
  List<Override> characterOverrides(FakeTtsService tts) => [
    ttsServiceProvider.overrideWithValue(tts),
    characterAnimationControllerFactoryProvider.overrideWithValue(
      FakeCharacterAnimationController.new,
    ),
    // Real script text, near-zero timing — see fast_transmission_repository.dart.
    transmissionRepositoryProvider.overrideWithValue(
      fastMockTransmissionRepository(TransmissionMockScenario.normalActive),
    ),
  ];

  testWidgets(
    'open Home, start the transmission, skip to reveal, accept, and return '
    'safely with the Dashboard reflecting acceptance',
    (tester) async {
      final tts = FakeTtsService(autoComplete: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureKeyValueStoreProvider.overrideWithValue(
              FakeSecureKeyValueStore(),
            ),
            authStateNotifierProvider.overrideWith(
              FakeAuthenticatedNotifier.new,
            ),
            ...characterOverrides(tts),
          ],
          child: const ForgeApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test User'), findsOneWidget);

      final viewMissionButton = find.widgetWithText(
        ForgeButton,
        'View Mission',
      );
      await tester.ensureVisible(viewMissionButton);
      await tester.pumpAndSettle();
      await tester.tap(viewMissionButton);
      await tester.pumpAndSettle();

      expect(find.text('The Watcher'), findsOneWidget);
      expect(tts.spokenTexts, isNotEmpty); // actually mid-transmission

      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ForgeButton, 'Accept Mission'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(ForgeButton, 'Mission Accepted'),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(DailyTransmissionPage), findsNothing);
      expect(find.text('Test User'), findsOneWidget);
      expect(
        find.widgetWithText(ForgeButton, 'Continue Mission'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the system back gesture closes the transmission and stops audio',
    (tester) async {
      final tts = FakeTtsService(autoComplete: false);
      final container = ProviderContainer(
        overrides: [
          secureKeyValueStoreProvider.overrideWithValue(
            FakeSecureKeyValueStore(),
          ),
          authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
          ...characterOverrides(tts),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: ForgeTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final viewMissionButton = find.widgetWithText(
        ForgeButton,
        'View Mission',
      );
      await tester.ensureVisible(viewMissionButton);
      await tester.pumpAndSettle();
      await tester.tap(viewMissionButton);
      await tester.pumpAndSettle();
      expect(find.byType(DailyTransmissionPage), findsOneWidget);

      final stopsBeforeBack = tts.stopCalls;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(DailyTransmissionPage), findsNothing);
      expect(tts.stopCalls, greaterThan(stopsBeforeBack));
    },
  );

  testWidgets(
    'signing out while the transmission is open stops active speech',
    (tester) async {
      final tts = FakeTtsService(autoComplete: false);
      final container = ProviderContainer(
        overrides: [
          secureKeyValueStoreProvider.overrideWithValue(
            FakeSecureKeyValueStore(),
          ),
          authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
          ...characterOverrides(tts),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: ForgeTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final viewMissionButton = find.widgetWithText(
        ForgeButton,
        'View Mission',
      );
      await tester.ensureVisible(viewMissionButton);
      await tester.pumpAndSettle();
      await tester.tap(viewMissionButton);
      await tester.pumpAndSettle();
      expect(tts.spokenTexts, isNotEmpty);

      final stopsBeforeSignOut = tts.stopCalls;
      await container.read(authStateNotifierProvider.notifier).signOut();
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(tts.stopCalls, greaterThan(stopsBeforeSignOut));
    },
  );
}
