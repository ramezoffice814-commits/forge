import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/auth/presentation/sign_up_page.dart';
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
      child: MaterialApp(theme: ForgeTheme.dark(), home: const SignUpPage()),
    );
  }

  testWidgets('shows validation errors for every empty required field', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.widgetWithText(ForgeButton, 'Create Account'));
    await tester.pump();

    expect(find.text('Display name is required.'), findsOneWidget);
    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(find.text('Confirm your password.'), findsOneWidget);
    expect(
      find.text(
        'You must accept the Terms of Service and Privacy Policy to continue.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows a mismatch error when confirm password differs', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'Alex Rivera',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'alex@forge.app',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'longpassword1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'different1',
    );
    await tester.tap(find.widgetWithText(ForgeButton, 'Create Account'));
    await tester.pump();

    expect(find.text("Passwords don't match."), findsOneWidget);
  });

  testWidgets(
    'creating an already-registered account shows the duplicate-email error',
    (tester) async {
      await tester.pumpWidget(wrap());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'),
        'Demo Warrior',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'demo@forge.app',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'longpassword1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'longpassword1',
      );
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.widgetWithText(ForgeButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'An account with that email already exists. Try signing in instead.',
        ),
        findsOneWidget,
      );
    },
  );
}
