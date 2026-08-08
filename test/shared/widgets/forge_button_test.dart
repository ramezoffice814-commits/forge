import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/shared/widgets/forge_button.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ForgeTheme.dark(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('invokes onPressed when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(ForgeButton(label: 'Accept', onPressed: () => tapped = true)),
    );

    await tester.tap(find.text('Accept'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('does not invoke onPressed when disabled', (tester) async {
    await tester.pumpWidget(
      wrap(const ForgeButton(label: 'Disabled', onPressed: null)),
    );

    await tester.tap(find.text('Disabled'), warnIfMissed: false);
    await tester.pump();

    // No callback wired, and the widget should render at reduced opacity.
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Disabled'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 0.45);
  });
}
