import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/router/app_router.dart';
import 'package:forge/core/router/auth_redirect_policy.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_overrides.dart';

/// Always throws — used to prove [appRouterProvider]'s `errorBuilder`
/// surfaces a real exception honestly rather than mislabeling it as an
/// unmatched route (the real-device startup-routing incident this
/// guards against: docs/ANDROID_BETA_DEVICE_TEST.md).
class _ThrowingRedirectPolicy implements AuthRedirectPolicy {
  const _ThrowingRedirectPolicy();

  @override
  String? redirect(BuildContext context, GoRouterState state) {
    throw StateError('synthetic startup failure for test purposes');
  }
}

void main() {
  testWidgets('an unmatched location renders NotFoundPage', (tester) async {
    final container = ProviderContainer(
      overrides: authenticatedTestOverrides(),
    );
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

    router.go('/does-not-exist');
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
    expect(find.textContaining('/does-not-exist'), findsOneWidget);
  });

  testWidgets(
    'an exception thrown during redirect resolution is surfaced honestly, '
    'not mislabeled as an unmatched route',
    (tester) async {
      // Regression test for the real-device startup-routing incident: a
      // release+mock safety guard threw during redirect resolution, and
      // errorBuilder's old hardcoded "No route for '/splash'." message
      // made a real startup exception indistinguishable from a genuinely
      // unregistered route. errorBuilder must now show the real error.
      final container = ProviderContainer(
        overrides: [
          ...authenticatedTestOverrides(),
          authRedirectPolicyProvider.overrideWithValue(
            const _ThrowingRedirectPolicy(),
          ),
        ],
      );
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

      expect(find.text('Page not found'), findsOneWidget);
      expect(
        find.textContaining('synthetic startup failure for test purposes'),
        findsOneWidget,
      );
      expect(find.textContaining('No route for'), findsNothing);
    },
  );
}
