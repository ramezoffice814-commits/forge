import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/router/app_router.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_overrides.dart';

void main() {
  Future<GoRouterHarness> pump(
    WidgetTester tester, {
    required List<Override> overrides,
  }) async {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: ForgeTheme.dark(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return GoRouterHarness(router);
  }

  testWidgets(
    'unauthenticated + onboarding not completed lands on onboarding',
    (tester) async {
      final harness = await pump(
        tester,
        overrides: unauthenticatedTestOverrides(onboardingCompleted: false),
      );
      expect(harness.location, '/onboarding');
    },
  );

  testWidgets('unauthenticated + onboarding completed lands on sign-in', (
    tester,
  ) async {
    final harness = await pump(
      tester,
      overrides: unauthenticatedTestOverrides(onboardingCompleted: true),
    );
    expect(harness.location, '/sign-in');
  });

  testWidgets('authenticated lands on home', (tester) async {
    final harness = await pump(tester, overrides: authenticatedTestOverrides());
    expect(harness.location, '/home');
  });

  testWidgets(
    'unauthenticated visiting a protected route is sent to sign-in with the destination preserved',
    (tester) async {
      final harness = await pump(
        tester,
        overrides: unauthenticatedTestOverrides(onboardingCompleted: true),
      );

      harness.router.go('/rank');
      await tester.pumpAndSettle();

      expect(harness.location, '/sign-in?redirect=%2Frank');
    },
  );

  testWidgets('unauthenticated visiting /settings (Roadmap Item 16) is sent to '
      'sign-in with the destination preserved — the same authenticated-only '
      'gating every other protected route already gets, not a special case', (
    tester,
  ) async {
    final harness = await pump(
      tester,
      overrides: unauthenticatedTestOverrides(onboardingCompleted: true),
    );

    harness.router.go('/settings');
    await tester.pumpAndSettle();

    expect(harness.location, '/sign-in?redirect=%2Fsettings');
  });

  testWidgets('authenticated user can reach /settings directly', (
    tester,
  ) async {
    final harness = await pump(tester, overrides: authenticatedTestOverrides());

    harness.router.go('/settings');
    await tester.pumpAndSettle();

    expect(harness.location, '/settings');
  });

  testWidgets('authenticated user visiting sign-in is bounced to home', (
    tester,
  ) async {
    final harness = await pump(tester, overrides: authenticatedTestOverrides());

    harness.router.go('/sign-in');
    await tester.pumpAndSettle();

    expect(harness.location, '/home');
  });

  testWidgets(
    'authenticated user visiting sign-in with a preserved redirect target lands there instead of home',
    (tester) async {
      final harness = await pump(
        tester,
        overrides: authenticatedTestOverrides(),
      );

      harness.router.go('/sign-in?redirect=%2Fprogress');
      await tester.pumpAndSettle();

      expect(harness.location, '/progress');
    },
  );
}

class GoRouterHarness {
  GoRouterHarness(this.router);

  final GoRouter router;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}
