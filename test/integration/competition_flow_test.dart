// Integration coverage for the fair-competition system: a real mission
// completion produces a competitive weekly-score update, is reflected on
// the Dashboard's competition snapshot, and is fully cleared on sign-out.
// Mirrors `progression_flow_test.dart`'s approach (real ForgeApp, real
// navigation) rather than a device-based `integration_test`.
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
import 'package:forge/features/competition/presentation/providers/competition_controller.dart';
import 'package:forge/features/competition/presentation/providers/competition_providers.dart';
import 'package:forge/features/competition/presentation/providers/competition_state.dart';
import 'package:forge/features/progression/presentation/providers/progression_providers.dart';
import 'package:forge/shared/widgets/forge_button.dart';

import '../support/fake_auth_overrides.dart';
import '../support/fake_secure_key_value_store.dart';
import '../support/fast_transmission_repository.dart';

void main() {
  testWidgets(
    'completing a mission creates a competitive weekly-score preview, is '
    'reflected on the Dashboard, and is cleared on sign-out',
    (tester) async {
      final tts = FakeTtsService(autoComplete: false);
      final fixedNow = DateTime.utc(2026, 8, 10, 9);
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
          competitionClockProvider.overrideWithValue(() => fixedNow),
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
      final competitionRepository = container.read(
        competitionRepositoryProvider,
      );

      await container.read(competitionControllerProvider.notifier).ready;
      final completionsBefore = (await competitionRepository.completionsForUser(
        userId,
      )).length;

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

      // Back to Dashboard so its competition snapshot is the visible,
      // active route.
      await tester.pageBack();
      await tester.pumpAndSettle();

      // 1. The completion was recorded as a competitive completion.
      expect(
        (await competitionRepository.completionsForUser(userId)).length,
        completionsBefore + 1,
      );

      // 2. The competition controller reflects a positive weekly score
      //    preview, explicitly marked provisional.
      final competitionState = container.read(competitionControllerProvider);
      expect(competitionState, isA<CompetitionReady>());
      final ready = competitionState as CompetitionReady;
      expect(ready.current.weeklyScore.cappedScore, greaterThan(0));
      expect(ready.current.weeklyScore.provisionalOnly, isTrue);

      // 3. Dashboard shows the compact competition snapshot referencing the
      //    current league.
      await tester.pumpAndSettle();
      expect(
        find.textContaining('${ready.current.league.name} League'),
        findsOneWidget,
      );

      // 4. Signing out clears all local competition state for this user.
      await container.read(authStateNotifierProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(await competitionRepository.completionsForUser(userId), isEmpty);
    },
  );
}
