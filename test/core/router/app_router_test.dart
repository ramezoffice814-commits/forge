import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/router/app_router.dart';
import 'package:forge/core/theme/forge_theme.dart';

import '../../support/fake_auth_overrides.dart';

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
}
