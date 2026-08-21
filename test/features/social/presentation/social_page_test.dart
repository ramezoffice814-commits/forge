import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/social/data/mock/mock_social_seeder.dart';
import 'package:forge/features/social/presentation/pages/social_page.dart';
import 'package:forge/features/social/presentation/providers/social_providers.dart';

import '../../../support/fake_auth_overrides.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 8, 10, 9);

  Widget wrap({SocialMockScenario scenario = SocialMockScenario.normal}) {
    return ProviderScope(
      overrides: [
        authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
        socialClockProvider.overrideWithValue(() => fixedNow),
        socialMockScenarioProvider.overrideWithValue(scenario),
      ],
      child: MaterialApp(theme: ForgeTheme.dark(), home: const SocialPage()),
    );
  }

  testWidgets(
    'shows a seeded pending request, friends list, and activity feed',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Requests'), findsOneWidget);
      expect(find.textContaining('wants to be friends'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
    },
  );

  testWidgets('accepting a request moves it into the friends list', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('wants to be friends'), findsNothing);
    expect(find.text('Friend request accepted.'), findsOneWidget);
  });

  testWidgets('rejecting a request removes it without creating a friendship', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.cancel_outlined));
    await tester.pumpAndSettle();

    expect(find.textContaining('wants to be friends'), findsNothing);
    expect(find.text('Friend request declined.'), findsOneWidget);
  });

  testWidgets('removing a friend shows a confirmation message', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_remove_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Friend removed.'), findsOneWidget);
  });

  testWidgets(
    'the empty scenario shows empty states for friends and activity',
    (tester) async {
      await tester.pumpWidget(wrap(scenario: SocialMockScenario.empty));
      await tester.pumpAndSettle();

      expect(find.text('No friends yet'), findsOneWidget);
      expect(find.text('No activity yet'), findsOneWidget);
      expect(find.text('Requests'), findsNothing); // section hidden when empty
    },
  );

  testWidgets('friend and request rows expose accessible semantics', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('Level .* League')), findsWidgets);
    handle.dispose();
  });
}
