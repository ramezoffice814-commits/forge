import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/router/app_routes.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/onboarding/presentation/onboarding_page.dart';
import 'package:forge/features/onboarding/presentation/onboarding_status.dart';
import 'package:forge/features/onboarding/presentation/onboarding_status_notifier.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fake_secure_key_value_store.dart';

void main() {
  Widget wrap({bool reduceMotion = false}) {
    final router = GoRouter(
      initialLocation: AppRoutePaths.onboarding,
      routes: [
        GoRoute(
          path: AppRoutePaths.onboarding,
          name: AppRouteNames.onboarding,
          builder: (context, state) => const OnboardingPage(),
        ),
        GoRoute(
          path: AppRoutePaths.signIn,
          name: AppRouteNames.signIn,
          builder: (context, state) =>
              const Scaffold(body: Text('SIGN IN STUB')),
        ),
        GoRoute(
          path: AppRoutePaths.signUp,
          name: AppRouteNames.signUp,
          builder: (context, state) =>
              const Scaffold(body: Text('SIGN UP STUB')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: MaterialApp.router(
          theme: ForgeTheme.dark(),
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('shows the first page on launch', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('PROVE YOU CAN'), findsOneWidget);
    expect(find.text('Daily discipline, compounding.'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
  });

  testWidgets('Next advances and Back returns, preserving progress', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('DAILY TRANSMISSION'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('PROVE YOU CAN'), findsOneWidget);
  });

  testWidgets('Skip marks onboarding complete and goes to sign-in', (
    tester,
  ) async {
    final store = FakeSecureKeyValueStore();
    final container = ProviderContainer(
      overrides: [secureKeyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: AppRoutePaths.onboarding,
      routes: [
        GoRoute(
          path: AppRoutePaths.onboarding,
          name: AppRouteNames.onboarding,
          builder: (context, state) => const OnboardingPage(),
        ),
        GoRoute(
          path: AppRoutePaths.signIn,
          name: AppRouteNames.signIn,
          builder: (context, state) =>
              const Scaffold(body: Text('SIGN IN STUB')),
        ),
      ],
    );

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

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('SIGN IN STUB'), findsOneWidget);
    expect(
      container.read(onboardingStatusProvider),
      isA<OnboardingStatusLoaded>().having(
        (s) => s.completed,
        'completed',
        isTrue,
      ),
    );
  });

  testWidgets('finishing the last page goes to sign-up', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('SIGN UP STUB'), findsOneWidget);
  });

  testWidgets(
    'reduced motion collapses the page-indicator animation duration',
    (tester) async {
      await tester.pumpWidget(wrap(reduceMotion: true));
      await tester.pumpAndSettle();

      final indicators = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(indicators, hasLength(4));
      for (final indicator in indicators) {
        expect(indicator.duration, Duration.zero);
      }
    },
  );
}
