import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/character/domain/entities/character_profile.dart';
import 'package:forge/features/character/domain/entities/character_state.dart';
import 'package:forge/features/character/presentation/widgets/forge_character_view.dart';

void main() {
  Widget wrap(CharacterState state, {bool reducedMotion = false}) {
    return MaterialApp(
      theme: ForgeTheme.dark(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: ForgeCharacterView(
            profile: CharacterProfile.watcher,
            state: state,
          ),
        ),
      ),
    );
  }

  testWidgets('exposes a single accessible description, not per-decoration '
      'semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrap(CharacterState.idle));
    await tester.pump();

    expect(
      find.bySemanticsLabel(CharacterProfile.watcher.accessibilityDescription),
      findsOneWidget,
    );

    semantics.dispose();
  });

  testWidgets('unavailable state announces unavailable and shows the offline '
      'label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrap(CharacterState.unavailable));
    await tester.pump();

    expect(find.bySemanticsLabel('The Watcher unavailable'), findsOneWidget);
    expect(find.text('UNAVAILABLE OFFLINE'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('reduced motion renders without throwing and without a '
      'lingering ticker', (tester) async {
    await tester.pumpWidget(wrap(CharacterState.speaking, reducedMotion: true));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('renders for every supported character state without error', (
    tester,
  ) async {
    for (final state in CharacterState.values) {
      await tester.pumpWidget(wrap(state));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: state.toString());
    }
  });
}
