import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/progression/presentation/pages/achievements_grid_page.dart';
import 'package:forge/features/progression/presentation/pages/progression_page.dart';
import 'package:forge/features/progression/presentation/widgets/level_up_celebration.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../support/fake_auth_overrides.dart';

/// No router ancestor is needed for the page goldens — `context.goNamed`
/// only lives inside the "View all" button's onTap, which nothing here taps.
Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
    ],
    child: MaterialApp(theme: ForgeTheme.dark(), home: child),
  );
}

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

    await tester.pumpWidget(_wrap(child));
    await tester.pumpAndSettle();
  }

  testWidgets('progression page — mobile reference size', (tester) async {
    await pumpAtSize(tester, const Size(412, 1600), const ProgressionPage());
    await expectLater(
      find.byType(ProgressionPage),
      matchesGoldenFile('goldens/progression_mobile.png'),
    );
  });

  testWidgets('progression page — wide/tablet reference size', (tester) async {
    await pumpAtSize(tester, const Size(1024, 1300), const ProgressionPage());
    await expectLater(
      find.byType(ProgressionPage),
      matchesGoldenFile('goldens/progression_wide.png'),
    );
  });

  testWidgets('achievements grid', (tester) async {
    await pumpAtSize(
      tester,
      const Size(412, 1800),
      const AchievementsGridPage(),
    );
    await expectLater(
      find.byType(AchievementsGridPage),
      matchesGoldenFile('goldens/achievements_grid.png'),
    );
  });

  testWidgets('level-up celebration', (tester) async {
    tester.view.physicalSize = const Size(412, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.dark(),
        home: Scaffold(
          body: Center(
            child: LevelUpCelebration(
              levelNumber: 5,
              levelTitle: 'Builder',
              reducedMotion: true,
              onDismiss: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LevelUpCelebration),
      matchesGoldenFile('goldens/level_up_celebration.png'),
    );
  });
}
