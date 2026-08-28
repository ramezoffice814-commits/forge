import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/progression/presentation/widgets/level_up_celebration.dart';

void main() {
  testWidgets('shows the level number and title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.dark(),
        home: Scaffold(
          body: LevelUpCelebration(
            levelNumber: 5,
            levelTitle: 'Builder',
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Level 5'), findsOneWidget);
    expect(find.textContaining('Builder'), findsOneWidget);
  });

  testWidgets('tapping the close button invokes onDismiss', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.dark(),
        home: Scaffold(
          body: LevelUpCelebration(
            levelNumber: 2,
            levelTitle: 'Initiate',
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(dismissed, isTrue);
  });

  testWidgets('reducedMotion=true still renders without animating '
      'indefinitely (settles immediately)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.dark(),
        home: Scaffold(
          body: LevelUpCelebration(
            levelNumber: 3,
            levelTitle: 'Initiate',
            reducedMotion: true,
            onDismiss: () {},
          ),
        ),
      ),
    );
    // A single pump (no explicit duration) is enough because the
    // reduced-motion animation duration is zero.
    await tester.pump();

    expect(find.textContaining('Level 3'), findsOneWidget);
  });

  testWidgets('never loops: the animation controller settles and stays put', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.dark(),
        home: Scaffold(
          body: LevelUpCelebration(
            levelNumber: 4,
            levelTitle: 'Initiate',
            onDismiss: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    // pumpAndSettle() throwing would mean the animation never stopped
    // scheduling frames — reaching this line is the assertion.
    expect(find.textContaining('Level 4'), findsOneWidget);
  });
}
