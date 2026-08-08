import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/app.dart';
import 'package:forge/shared/widgets/forge_bottom_navigation_bar.dart';

import '../../support/fake_auth_overrides.dart';

void main() {
  Finder navTab(String label) => find.descendant(
    of: find.byType(ForgeBottomNavigationBar),
    matching: find.text(label),
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
    expect(find.text('My League'), findsOneWidget);

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

    // Every tab now has real content, so this exercises
    // StatefulShellRoute.indexedStack's preservation mechanism through the
    // Rank tab's own local widget state instead: its TabBar's selected
    // sub-tab (My League/Season/Hall of Fame) should survive switching away
    // to another bottom-nav tab and back, rather than resetting to the
    // first sub-tab every time Rank remounts.
    await tester.tap(navTab('Rank'));
    await tester.pumpAndSettle();

    expect(find.text('My League'), findsOneWidget);
    await tester.tap(find.text('Season'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Season 1'), findsOneWidget);

    await tester.tap(navTab('Home'));
    await tester.pumpAndSettle();
    await tester.tap(navTab('Rank'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Season 1'), findsOneWidget);
  });
}
