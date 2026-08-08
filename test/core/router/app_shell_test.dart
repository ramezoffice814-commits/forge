import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/app.dart';
import 'package:forge/shared/widgets/forge_bottom_navigation_bar.dart';
import 'package:forge/shared/widgets/forge_button.dart';

import '../../support/fake_auth_overrides.dart';

void main() {
  Finder navTab(String label) => find.descendant(
    of: find.byType(ForgeBottomNavigationBar),
    matching: find.text(label),
  );

  Finder tapCounterButton() => find.widgetWithText(
    ForgeButton,
    'Tap (verifies tab state survives switching)',
  );

  Future<void> pumpAuthenticatedApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authenticatedTestOverrides(),
        child: const ForgeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('switches between all five tabs', (tester) async {
    await pumpAuthenticatedApp(tester);

    // Home is the initial route.
    expect(find.text('10-Minute Full-Body Stretch'), findsOneWidget);

    await tester.tap(navTab('Rank'));
    await tester.pumpAndSettle();
    expect(find.textContaining('weekly league podium'), findsOneWidget);

    await tester.tap(navTab('Progress'));
    await tester.pumpAndSettle();
    expect(find.textContaining('XP (preview'), findsOneWidget);

    await tester.tap(navTab('Awards'));
    await tester.pumpAndSettle();
    expect(find.text('First Steps'), findsOneWidget);

    await tester.tap(navTab('Profile'));
    await tester.pumpAndSettle();
    expect(find.textContaining('achievement(s) unlocked'), findsOneWidget);

    await tester.tap(navTab('Home'));
    await tester.pumpAndSettle();
    expect(find.text('10-Minute Full-Body Stretch'), findsOneWidget);
  });

  testWidgets('preserves a tab\'s state when switching away and back', (
    tester,
  ) async {
    await pumpAuthenticatedApp(tester);

    // Home now has real (stateless) dashboard content, so this checks
    // state preservation on a still-placeholder tab (Rank) instead — the
    // mechanism under test is StatefulShellRoute.indexedStack itself, not
    // anything Home-specific.
    await tester.tap(navTab('Rank'));
    await tester.pumpAndSettle();

    expect(find.text('Tapped 0 times'), findsOneWidget);

    await tester.tap(tapCounterButton());
    await tester.pump();
    expect(find.text('Tapped 1 times'), findsOneWidget);

    await tester.tap(navTab('Home'));
    await tester.pumpAndSettle();
    await tester.tap(navTab('Rank'));
    await tester.pumpAndSettle();

    expect(find.text('Tapped 1 times'), findsOneWidget);
  });
}
