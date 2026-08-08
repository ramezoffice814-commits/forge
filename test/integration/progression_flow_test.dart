// Integration coverage for the progression system: a real mission
// completion produces an XP preview, updates the progression profile,
// potentially unlocks achievements, is reflected on the Dashboard's level
// badge, and is fully cleared on sign-out. Run under plain `flutter test`
// against the real app/router (see `auth_onboarding_flow_test.dart` for why
// this repo takes that approach instead of device-based `integration_test`).
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
import 'package:forge/features/progression/presentation/providers/progression_controller.dart';
import 'package:forge/features/progression/presentation/providers/progression_providers.dart';
import 'package:forge/features/progression/presentation/providers/progression_state.dart';
import 'package:forge/features/progression/presentation/widgets/level_badge.dart';
import 'package:forge/shared/widgets/forge_button.dart';

import '../support/fake_auth_overrides.dart';
import '../support/fake_secure_key_value_store.dart';
import '../support/fast_transmission_repository.dart';

void main() {
  testWidgets(
    'completing a mission creates an XP preview, updates progression, is '
    'reflected on the Dashboard level badge, and is cleared on sign-out',
    (tester) async {
      final tts = FakeTtsService(autoComplete: false);
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
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ForgeApp(),
        ),
      );
      await tester.pumpAndSettle();

      final userId = container.read(currentProgressionUserIdProvider);
      final repository = container.read(progressionRepositoryProvider);

      await container.read(progressionControllerProvider.notifier).ready;
      final completionsBefore = repository.completionsForUser(userId).length;

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

      // Dashboard -> ActiveMissionPage -> Start -> log full progress ->
      // Submit. The `normalActive` scenario deterministically selects the
      // 10-minute full-body stretch mission (timer progress).
      await tester.tap(find.widgetWithText(ForgeButton, 'Continue Mission'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ForgeButton, 'Start'));
      await tester.pumpAndSettle();

      final addFiveMinutes = find.widgetWithText(ForgeButton, '+5 min');
      await tester.tap(addFiveMinutes);
      await tester.pumpAndSettle();
      await tester.tap(addFiveMinutes);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ForgeButton, 'Submit'));
      await tester.pumpAndSettle();

      // Back to Dashboard so its level badge is the visible, active route.
      await tester.pageBack();
      await tester.pumpAndSettle();

      // 1. Mission completion created an XP preview and recorded the
      //    completion.
      expect(
        repository.completionsForUser(userId).length,
        completionsBefore + 1,
      );
      final progressionState = container.read(progressionControllerProvider);
      expect(progressionState, isA<ProgressionReady>());
      final ready = progressionState as ProgressionReady;
      expect(ready.lastXpEvaluation, isNotNull);
      expect(ready.lastXpEvaluation!.provisionalOnly, isTrue);

      // 2. The XP preview updated the progression profile.
      expect(ready.aggregate.profile.provisionalXp, greaterThan(0));

      // 3. Dashboard's level badge reflects the (possibly new) level.
      await tester.pumpAndSettle();
      final badge = tester.widget<LevelBadge>(find.byType(LevelBadge));
      expect(badge.levelNumber, ready.aggregate.profile.currentLevel);

      // 4. Signing out clears all local progression state for this user.
      await container.read(authStateNotifierProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(repository.completionsForUser(userId), isEmpty);
    },
  );
}
