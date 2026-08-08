import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
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
}
