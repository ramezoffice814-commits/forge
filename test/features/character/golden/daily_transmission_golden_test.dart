import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/character/data/mock/fake_character_animation_controller.dart';
import 'package:forge/features/character/data/mock/fake_tts_service.dart';
import 'package:forge/features/character/data/transmission_repository_provider.dart';
import 'package:forge/features/character/presentation/controllers/daily_transmission_controller.dart';
import 'package:forge/features/character/presentation/daily_transmission_page.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../support/character_test_harness.dart';

void main() {
  setUpAll(() {
    // Golden tests must not depend on a network font fetch.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpAtSize(WidgetTester tester, Size size, Widget child) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
  }

  testWidgets('incoming transmission', (tester) async {
    final engine = FakeCharacterAnimationController(autoComplete: false);
    final harness = TransmissionTestHarness();
    await pumpAtSize(
      tester,
      const Size(412, 900),
      ProviderScope(
        overrides: harness.overrides(
          extra: [
            characterAnimationControllerFactoryProvider.overrideWithValue(
              () => engine,
            ),
          ],
        ),
        child: MaterialApp(
          theme: ForgeTheme.dark(),
          home: const DailyTransmissionPage(),
        ),
      ),
    );

    await expectLater(
      find.byType(DailyTransmissionPage),
      matchesGoldenFile('goldens/transmission_incoming.png'),
    );
  });

  testWidgets('speaking with subtitles', (tester) async {
    final harness = TransmissionTestHarness(
      tts: FakeTtsService(autoComplete: false),
    );
    await pumpAtSize(tester, const Size(412, 900), harness.page());

    await expectLater(
      find.byType(DailyTransmissionPage),
      matchesGoldenFile('goldens/transmission_speaking.png'),
    );
  });

  testWidgets('mission revealed', (tester) async {
    final harness = TransmissionTestHarness();
    await pumpAtSize(tester, const Size(412, 900), harness.page());

    await expectLater(
      find.byType(DailyTransmissionPage),
      matchesGoldenFile('goldens/transmission_revealed.png'),
    );
  });

  testWidgets('recovery transmission', (tester) async {
    final harness = TransmissionTestHarness();
    await pumpAtSize(
      tester,
      const Size(412, 900),
      harness.page(scenario: TransmissionMockScenario.recovery),
    );

    await expectLater(
      find.byType(DailyTransmissionPage),
      matchesGoldenFile('goldens/transmission_recovery.png'),
    );
  });

  testWidgets('wide layout', (tester) async {
    final harness = TransmissionTestHarness();
    await pumpAtSize(tester, const Size(1100, 900), harness.page());

    await expectLater(
      find.byType(DailyTransmissionPage),
      matchesGoldenFile('goldens/transmission_wide.png'),
    );
  });
}
