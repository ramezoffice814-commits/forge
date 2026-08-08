import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/missions/presentation/widgets/mission_explanation_panel.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ForgeTheme.dark(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders nothing when there are no reasons', (tester) async {
    await tester.pumpWidget(wrap(const MissionExplanationPanel(reasons: [])));
    expect(find.text('Why this mission?'), findsNothing);
  });

  testWidgets('starts collapsed by default, hiding the reasons', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const MissionExplanationPanel(
          reasons: ['Fits your 15-minute availability.'],
        ),
      ),
    );

    expect(find.text('Why this mission?'), findsOneWidget);
    expect(find.text('Fits your 15-minute availability.'), findsNothing);
  });

  testWidgets('tapping the header expands and shows up to 3 reasons', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const MissionExplanationPanel(
          reasons: [
            'Fits your 15-minute availability.',
            'Matches your preferred Coding category.',
            'Not recently repeated.',
            'A fourth reason that should be truncated.',
          ],
        ),
      ),
    );

    await tester.tap(find.text('Why this mission?'));
    await tester.pumpAndSettle();

    expect(find.text('Fits your 15-minute availability.'), findsOneWidget);
    expect(
      find.text('Matches your preferred Coding category.'),
      findsOneWidget,
    );
    expect(find.text('Not recently repeated.'), findsOneWidget);
    expect(
      find.text('A fourth reason that should be truncated.'),
      findsNothing,
    );

    // Tapping again collapses it.
    await tester.tap(find.text('Why this mission?'));
    await tester.pumpAndSettle();
    expect(find.text('Fits your 15-minute availability.'), findsNothing);
  });

  testWidgets('the toggle carries a semantic label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(const MissionExplanationPanel(reasons: ['A reason.'])),
    );

    expect(find.bySemanticsLabel('Why this mission?'), findsOneWidget);

    semantics.dispose();
  });
}
