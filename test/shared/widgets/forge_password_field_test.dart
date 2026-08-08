import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/shared/widgets/forge_password_field.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ForgeTheme.dark(),
      home: Scaffold(body: child),
    );
  }

  testWidgets(
    'obscures text by default and reveals it when the eye icon is tapped',
    (tester) async {
      final controller = TextEditingController(text: 'super-secret');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(ForgePasswordField(label: 'Password', controller: controller)),
      );

      TextField textField() => tester.widget<TextField>(find.byType(TextField));

      expect(textField().obscureText, isTrue);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(textField().obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(textField().obscureText, isTrue);
    },
  );
}
