import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/app.dart';
import 'package:forge/features/dashboard/presentation/widgets/dashboard_quick_actions.dart';
import 'package:forge/shared/widgets/forge_bottom_navigation_bar.dart';
import 'package:forge/shared/widgets/forge_button.dart';

import '../support/fake_auth_overrides.dart';

void main() {
  Future<void> pumpAuthenticatedApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authenticatedTestOverrides(),
        child: const ForgeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('authenticated session lands on the real Home dashboard', (
    tester,
  ) async {
    await pumpAuthenticatedApp(tester);

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('10-Minute Full-Body Stretch'), findsOneWidget);
  });

  testWidgets('Home -> Rank via the league preview card', (tester) async {
    await pumpAuthenticatedApp(tester);

    final button = find.widgetWithText(ForgeButton, 'View Rank');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('My League'), findsOneWidget);
    // The bottom nav should agree Rank is now the active tab.
    expect(
      find.descendant(
        of: find.byType(ForgeBottomNavigationBar),
        matching: find.text('Rank'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Home -> Progress via a quick action', (tester) async {
    await pumpAuthenticatedApp(tester);

    // "Progress" also appears as a bottom-nav tab label — scope to the
    // dashboard's own quick-actions row to disambiguate.
    final action = find.descendant(
      of: find.byType(DashboardQuickActions),
      matching: find.text('Progress'),
    );
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.textContaining('XP (preview'), findsOneWidget);
  });
}
