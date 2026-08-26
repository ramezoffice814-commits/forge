import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/auth/presentation/auth_state.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/settings/presentation/widgets/settings_account_section.dart';

import '../../../support/fake_auth_overrides.dart';
import '../../../support/fake_secure_key_value_store.dart';

Widget _wrap(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: ForgeTheme.dark(),
      home: const Scaffold(body: SettingsAccountSection()),
    ),
  );
}

void main() {
  testWidgets('shows the signed-in user\'s display name and email', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: authenticatedTestOverrides(),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('test@forge.app'), findsOneWidget);
  });

  testWidgets('cancelling the sign-out dialog leaves the session untouched', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        ...authenticatedTestOverrides(),
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      container.read(authStateNotifierProvider).status,
      AuthStatus.authenticated,
    );
  });

  testWidgets('confirming sign-out actually signs the user out through the '
      'real auth flow', (tester) async {
    final container = ProviderContainer(
      overrides: [
        ...authenticatedTestOverrides(),
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    // Two "Sign out" texts now exist (the tile + the dialog action) —
    // tap the last one, which is the dialog's confirm button.
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();

    expect(
      container.read(authStateNotifierProvider).status,
      AuthStatus.unauthenticated,
    );
  });

  testWidgets('delete-account is wired to the real use case and surfaces '
      'the honest "not available yet" message — never a fake success, '
      'never an actual account change', (tester) async {
    final container = ProviderContainer(
      overrides: [
        ...authenticatedTestOverrides(),
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Account deletion is not available yet.'), findsOneWidget);
    // Never actually signed out or deleted anything.
    expect(
      container.read(authStateNotifierProvider).status,
      AuthStatus.authenticated,
    );
  });

  testWidgets('cancelling the delete-account dialog performs no action at '
      'all', (tester) async {
    final container = ProviderContainer(
      overrides: [
        ...authenticatedTestOverrides(),
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(container));
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Account deletion is not available yet.'), findsNothing);
    expect(
      container.read(authStateNotifierProvider).status,
      AuthStatus.authenticated,
    );
  });
}
