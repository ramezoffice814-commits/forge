import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/competition/presentation/pages/competition_page.dart';
import 'package:forge/features/competition/presentation/providers/competition_providers.dart';

import '../../../support/fake_auth_overrides.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 8, 10, 9);

  Widget wrap() {
    return ProviderScope(
      overrides: [
        authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
        competitionClockProvider.overrideWithValue(() => fixedNow),
      ],
      child: MaterialApp(
        theme: ForgeTheme.dark(),
        home: const CompetitionPage(),
      ),
    );
  }

  testWidgets('shows the current league, leaderboard, and movement preview '
      'once loaded', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('League'), findsWidgets);
    expect(find.textContaining('pts (preview)'), findsWidgets);
    expect(find.text('Test User (You)'), findsOneWidget);
  });

  testWidgets('switching to the Season tab shows season progress', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Season'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Season 1'), findsOneWidget);
    expect(find.textContaining('Week'), findsWidgets);
  });

  testWidgets('switching to the Hall of Fame tab shows historical records', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hall of Fame'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Reached Mythic League'), findsOneWidget);
  });

  testWidgets('the info button opens the fairness explanation sheet', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('How ranking works'), findsOneWidget);
    expect(
      find.textContaining('lifetime XP does not determine'),
      findsOneWidget,
    );
  });

  testWidgets('a brand-new user sees the rookie placement banner', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Placement Period'), findsOneWidget);
    expect(find.textContaining('account age never affects it'), findsOneWidget);
  });
}
