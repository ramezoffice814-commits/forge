import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/auth/presentation/sign_in_page.dart';
import 'package:forge/shared/widgets/forge_button.dart';

import '../../../support/fake_secure_key_value_store.dart';

void main() {
  Widget wrap() {
    return ProviderScope(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
      ],
      child: MaterialApp(theme: ForgeTheme.dark(), home: const SignInPage()),
    );
  }

  testWidgets('shows validation errors for empty fields on submit', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.widgetWithText(ForgeButton, 'Sign In'));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('shows a validation error for an invalid email format', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'not-an-email',
    );
    await tester.tap(find.widgetWithText(ForgeButton, 'Sign In'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets(
    'disables the submit button while authenticating, then shows an error banner and clears the password (keeping the email) on invalid credentials',
    (tester) async {
      await tester.pumpWidget(wrap());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'demo@forge.app',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'wrong-password',
      );
      await tester.tap(find.widgetWithText(ForgeButton, 'Sign In'));
      await tester.pump();

      // Mid-flight: the mock repository's simulated delay hasn't resolved yet.
      expect(find.text('Signing in…'), findsOneWidget);
      final button = tester.widget<ForgeButton>(
        find.widgetWithText(ForgeButton, 'Signing in…'),
      );
      expect(button.onPressed, isNull);

      await tester.pumpAndSettle();

      expect(
        find.text(
          "That email or password isn't right. Try again, or reset your password.",
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Email'))
            .controller!
            .text,
        'demo@forge.app',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Password'),
            )
            .controller!
            .text,
        isEmpty,
      );
    },
  );
}
