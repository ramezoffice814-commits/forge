import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/core/theme/forge_tokens.dart';
import 'package:forge/shared/widgets/forge_bottom_navigation_bar.dart';

void main() {
  const items = [
    ForgeNavItem(icon: Icons.home_outlined, label: 'Home'),
    ForgeNavItem(icon: Icons.emoji_events_outlined, label: 'Rank'),
  ];

  Widget wrap(Widget child, {bool reduceMotion = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        theme: ForgeTheme.dark(),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('invokes onTap with the tapped item\'s index', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      wrap(
        ForgeBottomNavigationBar(
          items: items,
          currentIndex: 0,
          onTap: (i) => tapped = i,
        ),
      ),
    );

    await tester.tap(find.text('Rank'));
    expect(tapped, 1);
  });

  testWidgets('reduced motion collapses the active-pill animation duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ForgeBottomNavigationBar(items: items, currentIndex: 0, onTap: (_) {}),
        reduceMotion: true,
      ),
    );

    final opacities = tester.widgetList<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacities, isNotEmpty);
    for (final opacity in opacities) {
      expect(opacity.duration, Duration.zero);
    }
  });

  testWidgets('normal motion uses a non-zero active-pill animation duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ForgeBottomNavigationBar(items: items, currentIndex: 0, onTap: (_) {}),
      ),
    );

    final opacities = tester.widgetList<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacities, isNotEmpty);
    for (final opacity in opacities) {
      expect(opacity.duration, isNot(Duration.zero));
    }
  });

  group('shellContentBottomClearance (Mobile Polish Pass 1)', () {
    final tokens = ForgeTokens.dark();

    test('is meaningfully larger than the plain page padding it replaces', () {
      final clearance = ForgeBottomNavigationBar.shellContentBottomClearance(
        tokens,
      );
      // The original bug: every shell tab used the same tokens.spacing.space4
      // (11.2) for every side, including the bottom edge next to this bar.
      // A real fix has to be substantially bigger than that, not a token
      // reshuffle that happens to compute back to roughly the same number.
      expect(clearance, greaterThan(tokens.spacing.space4 * 4));
    });

    test('equals the documented content height + margin + shadow bleed', () {
      final clearance = ForgeBottomNavigationBar.shellContentBottomClearance(
        tokens,
      );
      // 62 (this bar's own intrinsic content height) + tokens.spacing.space3
      // (the same outer bottom margin `build()` above gives this bar) + 24
      // (ForgeShadows.lg's blur/offset bleed allowance) — see
      // shellContentBottomClearance's own doc comment for what each term
      // represents; this pins the formula so a future edit to any one term
      // is a deliberate, visible change here too.
      expect(clearance, closeTo(62 + tokens.spacing.space3 + 24, 0.001));
    });
  });
}
