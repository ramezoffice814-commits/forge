import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/shared/widgets/authority_status_badge.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ForgeTheme.dark(),
      home: Scaffold(body: child),
    );
  }

  final expectedLabels = {
    AuthorityIndicator.pendingSync: 'Syncing…',
    AuthorityIndicator.provisional: 'Provisional',
    AuthorityIndicator.confirmed: 'Confirmed',
    AuthorityIndicator.conflict: 'Needs attention',
  };

  for (final indicator in AuthorityIndicator.values) {
    testWidgets('renders the expected label for $indicator', (tester) async {
      await tester.pumpWidget(wrap(AuthorityStatusBadge(indicator: indicator)));

      expect(find.text(expectedLabels[indicator]!), findsOneWidget);
    });
  }

  testWidgets('exposes an accessible semantics label naming the status', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(const AuthorityStatusBadge(indicator: AuthorityIndicator.confirmed)),
    );

    expect(find.bySemanticsLabel('Sync status: Confirmed'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('every indicator renders without throwing', (tester) async {
    for (final indicator in AuthorityIndicator.values) {
      await tester.pumpWidget(wrap(AuthorityStatusBadge(indicator: indicator)));
      await tester.pump();
    }
  });
}
