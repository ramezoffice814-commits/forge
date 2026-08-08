import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/progression/presentation/pages/progression_page.dart';
import 'package:go_router/go_router.dart';

import '../../../../support/fake_auth_overrides.dart';

void main() {
  Widget wrap() {
    final router = GoRouter(
      initialLocation: '/progress',
      routes: [
        GoRoute(
          path: '/progress',
          name: 'progress',
          builder: (context, state) => const ProgressionPage(),
        ),
        GoRoute(
          path: '/awards',
          name: 'awards',
          builder: (context, state) =>
              const Scaffold(body: Text('awards-page-marker')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
      ],
      child: MaterialApp.router(theme: ForgeTheme.dark(), routerConfig: router),
    );
  }

  testWidgets('shows level, title, and category growth once loaded', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('XP (preview'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Category growth'), findsOneWidget);
  });

  testWidgets('shows a recent-achievements preview with a working "View '
      'all" link to Awards', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('Recent achievements'), findsOneWidget);

    final viewAll = find.text('View all');
    await tester.ensureVisible(viewAll);
    await tester.pumpAndSettle();
    await tester.tap(viewAll);
    await tester.pumpAndSettle();

    expect(find.text('awards-page-marker'), findsOneWidget);
  });

  testWidgets('the XP preview is explicitly labeled non-authoritative', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('not yet confirmed'), findsOneWidget);
  });
}
