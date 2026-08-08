import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/app.dart';

import 'support/fake_auth_overrides.dart';

void main() {
  testWidgets('ForgeApp boots and shows the Home tab at the initial route', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authenticatedTestOverrides(),
        child: const ForgeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('10-Minute Full-Body Stretch'), findsOneWidget);
  });
}
