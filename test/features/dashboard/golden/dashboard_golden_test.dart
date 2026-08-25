// Image-comparison golden tests — platform-dependent rendering (see
// dart_test.yaml and docs/ARCHITECTURE.md's golden-test notes). Excluded
// from the standard `flutter test --exclude-tags=golden` run and executed
// on their own via `flutter test --tags=golden`.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_privacy_level.dart';
import 'package:forge/features/ai_coach/presentation/providers/ai_coach_providers.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/dashboard/data/dashboard_repository_provider.dart';
import 'package:forge/features/dashboard/data/mock/mock_dashboard_repository.dart';
import 'package:forge/features/dashboard/presentation/dashboard_page.dart';
import 'package:forge/features/missions/data/mock/mock_mission_context.dart';
import 'package:forge/features/missions/presentation/providers/mission_providers.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../support/fake_auth_overrides.dart';
import '../../../support/fake_secure_key_value_store.dart';

/// No router ancestor is needed here — `context.goNamed` calls only live
/// inside onTap closures nothing here ever taps, so a plain [MaterialApp]
/// is enough for rendering.
Widget _wrap(
  DashboardMockScenario scenario, {
  MockMissionContextScenario missionScenario =
      MockMissionContextScenario.normalActive,
}) {
  return ProviderScope(
    overrides: [
      secureKeyValueStoreProvider.overrideWithValue(FakeSecureKeyValueStore()),
      authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
      dashboardMockScenarioProvider.overrideWithValue(scenario),
      missionMockScenarioProvider.overrideWithValue(missionScenario),
      // AI insight text is dynamic (mock-generated) and not what this
      // golden verifies — pixel-comparing static dashboard layout. AI
      // disabled is itself a real, fully-supported user mode, so this
      // is an honest test configuration, not a workaround.
      aiPrivacyLevelProvider.overrideWith((ref) => AiPrivacyLevel.disabled),
    ],
    child: MaterialApp(theme: ForgeTheme.dark(), home: const DashboardPage()),
  );
}

void main() {
  setUpAll(() {
    // Golden tests must not depend on a network font fetch.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpAtSize(
    WidgetTester tester,
    Size size,
    DashboardMockScenario scenario, {
    MockMissionContextScenario missionScenario =
        MockMissionContextScenario.normalActive,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(scenario, missionScenario: missionScenario));
    await tester.pumpAndSettle();
  }

  testWidgets('main dashboard — mobile reference size', (tester) async {
    await pumpAtSize(
      tester,
      const Size(412, 1300),
      DashboardMockScenario.normalActive,
    );
    await expectLater(
      find.byType(DashboardPage),
      matchesGoldenFile('goldens/dashboard_mobile.png'),
    );
  });

  testWidgets('main dashboard — wide/tablet reference size', (tester) async {
    await pumpAtSize(
      tester,
      const Size(1024, 1100),
      DashboardMockScenario.normalActive,
    );
    await expectLater(
      find.byType(DashboardPage),
      matchesGoldenFile('goldens/dashboard_wide.png'),
    );
  });

  testWidgets('recovery dashboard state', (tester) async {
    await pumpAtSize(
      tester,
      const Size(412, 1400),
      DashboardMockScenario.recoveryMode,
      missionScenario: MockMissionContextScenario.recoveryMode,
    );
    await expectLater(
      find.byType(DashboardPage),
      matchesGoldenFile('goldens/dashboard_recovery.png'),
    );
  });
}
