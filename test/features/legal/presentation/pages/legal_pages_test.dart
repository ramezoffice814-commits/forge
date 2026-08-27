import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/legal/presentation/pages/privacy_policy_page.dart';
import 'package:forge/features/legal/presentation/pages/terms_of_service_page.dart';

Future<void> _pump(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(MaterialApp(theme: ForgeTheme.dark(), home: page));
  await tester.pumpAndSettle();
}

void main() {
  group('PrivacyPolicyPage', () {
    testWidgets('shows the pending-legal-review banner prominently — never '
        'presented as a finished, approved policy', (tester) async {
      await _pump(tester, const PrivacyPolicyPage());

      expect(find.textContaining('pending legal review'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
    });

    testWidgets(
      'describes actual current data handling honestly — no AI provider '
      'claim, no account-deletion claim that isn\'t true yet',
      (tester) async {
        await _pump(tester, const PrivacyPolicyPage());

        expect(find.textContaining('mock AI provider'), findsOneWidget);
        expect(find.textContaining('not implemented yet'), findsOneWidget);
      },
    );
  });

  group('TermsOfServicePage', () {
    testWidgets('shows the pending-legal-review banner and does not assert '
        'binding terms', (tester) async {
      await _pump(tester, const TermsOfServicePage());

      expect(find.textContaining('pending legal review'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(
        find.textContaining('does not yet have reviewed, approved Terms'),
        findsOneWidget,
      );
    });
  });
}
