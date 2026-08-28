// These are "integration tests" in the sense the roadmap item asks for —
// full first-launch → onboarding → sign-up → shell, restart, sign-out,
// protected-route, and password-reset flows — but run under plain
// `flutter test` rather than the device-based `integration_test` package
// (no emulator/device is attached in this environment; see item 1's
// blockers). Everything here exercises the real router, real
// AuthStateNotifier/OnboardingStatusNotifier, and real
// MockAuthRepository/LocalOnboardingRepository — only the storage backing
// is faked, since flutter_secure_storage's platform channel isn't
// available under `flutter test`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/app.dart';
import 'package:forge/core/router/app_router.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/auth/data/mock/mock_session_codec.dart';
import 'package:forge/features/auth/domain/entities/auth_session.dart';
import 'package:forge/features/auth/domain/entities/auth_user.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/onboarding/data/local_onboarding_repository.dart';
import 'package:forge/shared/widgets/forge_button.dart';

import '../support/fake_secure_key_value_store.dart';

void main() {
  testWidgets('first launch: onboarding -> sign-up -> authenticated shell', (
    tester,
  ) async {
    final store = FakeSecureKeyValueStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureKeyValueStoreProvider.overrideWithValue(store)],
        child: const ForgeApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Fresh install: no session, onboarding not completed.
    expect(find.text('PROVE YOU CAN'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(ForgeButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Prove you can.'), findsOneWidget); // sign-up header

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
      'longpassword1',
    );
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.widgetWithText(ForgeButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Alex Rivera'), findsOneWidget);
    expect(find.text('10-Minute Full-Body Stretch'), findsOneWidget);
  });

  testWidgets(
    'a restored session (simulated restart) lands directly on the authenticated shell',
    (tester) async {
      final store = FakeSecureKeyValueStore();
      await LocalOnboardingRepository(store).markCompleted();
      await store.write(
        'forge.auth.mock_session',
        MockSessionCodec.encode(
          AuthSession(
            user: AuthUser(
              id: 'restored-user',
              displayName: 'Restored User',
              email: 'restored@forge.app',
              createdAt: DateTime.utc(2026, 1, 1),
              onboardingCompleted: true,
            ),
            accessToken: 'mock-token-restored',
          ),
        ),
      );

      // A brand-new provider tree/widget tree over the same store simulates
      // a real process restart: nothing in-memory survives, only storage.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [secureKeyValueStoreProvider.overrideWithValue(store)],
          child: const ForgeApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restored User'), findsOneWidget);
    },
  );

  testWidgets('sign-out returns to the sign-in route', (tester) async {
    final store = FakeSecureKeyValueStore();
    await LocalOnboardingRepository(store).markCompleted();
    await store.write(
      'forge.auth.mock_session',
      MockSessionCodec.encode(
        AuthSession(
          user: AuthUser(
            id: 'signed-in-user',
            displayName: 'Signed In',
            email: 'signedin@forge.app',
            createdAt: DateTime.utc(2026, 1, 1),
            onboardingCompleted: true,
          ),
          accessToken: 'mock-token-signed-in',
        ),
      ),
    );

    final container = ProviderContainer(
      overrides: [secureKeyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: ForgeTheme.dark(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Signed In'), findsOneWidget);

    // There is no sign-out button in the UI yet — Profile's real content
    // (including a sign-out control) is out of scope for this roadmap
    // item, so this exercises the use case the way the eventual button
    // will: through AuthStateNotifier.
    await container.read(authStateNotifierProvider.notifier).signOut();
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets(
    'an unauthenticated visit to a protected route redirects to sign-in and returns there after signing in',
    (tester) async {
      final store = FakeSecureKeyValueStore();
      await LocalOnboardingRepository(store).markCompleted();

      final container = ProviderContainer(
        overrides: [secureKeyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: ForgeTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);

      router.go('/rank');
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'demo@forge.app',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'forgepass1',
      );
      await tester.tap(find.widgetWithText(ForgeButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('My League'), findsOneWidget);
    },
  );

  testWidgets('mock password reset flow shows a success confirmation', (
    tester,
  ) async {
    final store = FakeSecureKeyValueStore();
    await LocalOnboardingRepository(store).markCompleted();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureKeyValueStoreProvider.overrideWithValue(store)],
        child: const ForgeApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'demo@forge.app',
    );
    await tester.tap(
      find.widgetWithText(ForgeButton, 'Send Reset Instructions'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining("we've sent reset"), findsOneWidget);
  });
}
