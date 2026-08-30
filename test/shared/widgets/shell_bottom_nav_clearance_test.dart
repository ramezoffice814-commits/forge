// Mobile Polish Pass 1 regression coverage: the real-device UI audit
// found all five StatefulShellRoute branch-root pages (Home/Rank/
// Progress/Awards/Profile) reserved only `tokens.spacing.space4` (11.2px)
// of bottom clearance below their scrollable content, with no allowance
// for the floating ForgeBottomNavigationBar's own margin/shadow — the
// last card visually read as sliding under the nav bar. The fix routes
// every one of these scroll views through the single shared
// `ForgeBottomNavigationBar.shellContentBottomClearance` helper instead
// of five independently hand-picked values; these tests assert that
// contract directly (a structural padding check, not a pixel-diff golden)
// so a future edit can't silently drop back to the old uniform padding
// on any one tab without this failing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/core/theme/forge_tokens.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/competition/presentation/pages/competition_page.dart';
import 'package:forge/features/competition/presentation/providers/competition_providers.dart';
import 'package:forge/features/dashboard/data/dashboard_repository_provider.dart';
import 'package:forge/features/dashboard/data/mock/mock_dashboard_repository.dart';
import 'package:forge/features/dashboard/presentation/dashboard_page.dart';
import 'package:forge/features/missions/data/mock/mock_mission_context.dart';
import 'package:forge/features/missions/presentation/providers/mission_providers.dart';
import 'package:forge/features/profile/presentation/profile_page.dart';
import 'package:forge/features/progression/presentation/pages/achievements_grid_page.dart';
import 'package:forge/features/progression/presentation/pages/progression_page.dart';
import 'package:forge/shared/widgets/forge_bottom_navigation_bar.dart';

import '../../support/fake_auth_overrides.dart';
import '../../support/fake_secure_key_value_store.dart';

/// A genuinely narrow real-device reference width (smaller than any of
/// this app's existing golden reference sizes) — proves the extra
/// bottom-clearance padding doesn't trigger any overflow/layout error on
/// a small phone, not just that it exists.
const _narrowMobileSize = Size(360, 800);

void main() {
  final tokens = ForgeTokens.dark();
  final expectedClearance =
      ForgeBottomNavigationBar.shellContentBottomClearance(tokens);

  Future<void> pumpAtNarrowSize(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = _narrowMobileSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
  }

  EdgeInsets paddingOf(WidgetTester tester, Finder finder) {
    final widget = tester.widget(finder);
    return switch (widget) {
      SingleChildScrollView(:final padding) =>
        (padding ?? EdgeInsets.zero).resolve(TextDirection.ltr),
      ListView(:final padding) => (padding ?? EdgeInsets.zero).resolve(
        TextDirection.ltr,
      ),
      _ => throw StateError('Unexpected widget type: ${widget.runtimeType}'),
    };
  }

  testWidgets('Home (Dashboard) reserves the shared shell bottom clearance', (
    tester,
  ) async {
    await pumpAtNarrowSize(
      tester,
      ProviderScope(
        overrides: [
          secureKeyValueStoreProvider.overrideWithValue(
            FakeSecureKeyValueStore(),
          ),
          authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
          dashboardMockScenarioProvider.overrideWithValue(
            DashboardMockScenario.normalActive,
          ),
          missionMockScenarioProvider.overrideWithValue(
            MockMissionContextScenario.normalActive,
          ),
        ],
        child: MaterialApp(
          theme: ForgeTheme.dark(),
          home: const DashboardPage(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final padding = paddingOf(tester, find.byType(SingleChildScrollView));
    expect(padding.bottom, expectedClearance);
  });

  testWidgets('Rank (Competition) reserves the shared clearance on all '
      'three sub-tabs', (tester) async {
    final fixedNow = DateTime.utc(2026, 8, 10, 9);
    await pumpAtNarrowSize(
      tester,
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
          competitionClockProvider.overrideWithValue(() => fixedNow),
        ],
        child: MaterialApp(
          theme: ForgeTheme.dark(),
          home: const CompetitionPage(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      paddingOf(tester, find.byType(SingleChildScrollView)).bottom,
      expectedClearance,
    );

    await tester.tap(find.text('Season'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      paddingOf(tester, find.byType(SingleChildScrollView)).bottom,
      expectedClearance,
    );

    await tester.tap(find.text('Hall of Fame'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      paddingOf(tester, find.byType(SingleChildScrollView)).bottom,
      expectedClearance,
    );
  });

  testWidgets('Progress reserves the shared shell bottom clearance', (
    tester,
  ) async {
    await pumpAtNarrowSize(
      tester,
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
        ],
        child: MaterialApp(
          theme: ForgeTheme.dark(),
          home: const ProgressionPage(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final padding = paddingOf(tester, find.byType(SingleChildScrollView));
    expect(padding.bottom, expectedClearance);
  });

  testWidgets('Awards reserves the shared shell bottom clearance', (
    tester,
  ) async {
    await pumpAtNarrowSize(
      tester,
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
        ],
        child: MaterialApp(
          theme: ForgeTheme.dark(),
          home: const AchievementsGridPage(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final padding = paddingOf(tester, find.byType(ListView));
    expect(padding.bottom, expectedClearance);
  });

  testWidgets('Profile reserves the shared shell bottom clearance', (
    tester,
  ) async {
    await pumpAtNarrowSize(
      tester,
      ProviderScope(
        overrides: [
          authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
        ],
        child: MaterialApp(theme: ForgeTheme.dark(), home: const ProfilePage()),
      ),
    );

    expect(tester.takeException(), isNull);
    final padding = paddingOf(tester, find.byType(SingleChildScrollView));
    expect(padding.bottom, expectedClearance);
  });
}
