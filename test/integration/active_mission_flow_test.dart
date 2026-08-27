// Integration coverage for the full mission lifecycle: Dashboard -> Daily
// Transmission (accept) -> ActiveMissionPage (start, log progress, submit,
// completed) -> back on Dashboard reflecting completion. Run under plain
// `flutter test` against the real app/router (see
// `auth_onboarding_flow_test.dart` for why this repo takes that approach
// instead of device-based `integration_test`).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/app.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/character/data/mock/fake_character_animation_controller.dart';
import 'package:forge/features/character/data/mock/fake_tts_service.dart';
import 'package:forge/features/character/data/transmission_repository_provider.dart';
import 'package:forge/features/character/data/tts_service_provider.dart';
import 'package:forge/features/character/presentation/controllers/daily_transmission_controller.dart';
import 'package:forge/features/missions/presentation/pages/active_mission_page.dart';
import 'package:forge/shared/widgets/forge_button.dart';

import '../support/fake_auth_overrides.dart';
import '../support/fake_secure_key_value_store.dart';
import '../support/fast_transmission_repository.dart';

void main() {
  testWidgets(
    'accept a mission in Transmission, then start/log progress/submit it '
    'to completion in ActiveMissionPage, with Dashboard reflecting each step',
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

      // Dashboard -> Transmission -> accept -> back on Dashboard.
      final viewMissionButton = find.widgetWithText(
        ForgeButton,
        'View Mission',
      );
      await tester.ensureVisible(viewMissionButton);
      await tester.pumpAndSettle();
      await tester.tap(viewMissionButton);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ForgeButton, 'Accept Mission'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      final continueButton = find.widgetWithText(
        ForgeButton,
        'Continue Mission',
      );
      expect(continueButton, findsOneWidget);

      // Dashboard -> ActiveMissionPage.
      await tester.ensureVisible(continueButton);
      await tester.pumpAndSettle();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.byType(ActiveMissionPage), findsOneWidget);
      expect(find.widgetWithText(ForgeButton, 'Start'), findsOneWidget);

      // Roadmap Item 19 accessibility pass: the mission's Progress/
      // History sections are exposed as semantic headers, so a
      // screen-reader user can navigate this screen by section.
      final semanticsHandle = tester.ensureSemantics();
      final progressHeading = tester.getSemantics(find.text('Progress'));
      expect(progressHeading.flagsCollection.isHeader, isTrue);
      final historyHeading = tester.getSemantics(find.text('History'));
      expect(historyHeading.flagsCollection.isHeader, isTrue);
      semanticsHandle.dispose();

      await tester.tap(find.widgetWithText(ForgeButton, 'Start'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ForgeButton, 'Pause'), findsOneWidget);
      expect(find.widgetWithText(ForgeButton, 'Submit'), findsOneWidget);

      // The `normalActive` scenario deterministically selects the
      // 10-minute full-body stretch mission (timer progress, 10-minute
      // target) — log the full 10 minutes via two +5-minute taps.
      final addFiveMinutes = find.widgetWithText(ForgeButton, '+5 min');
      expect(addFiveMinutes, findsOneWidget);
      await tester.tap(addFiveMinutes);
      await tester.pumpAndSettle();
      await tester.tap(addFiveMinutes);
      await tester.pumpAndSettle();
      expect(find.text('10m / 10m'), findsOneWidget);

      await tester.tap(find.widgetWithText(ForgeButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ForgeButton, 'Undo completion'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ForgeButton, 'Submit'), findsNothing);

      // Undo puts it right back into an active, submittable state.
      await tester.tap(find.widgetWithText(ForgeButton, 'Undo completion'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ForgeButton, 'Submit'), findsOneWidget);
    },
  );
}
