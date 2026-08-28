import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/router/app_routes.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/dashboard/data/dashboard_repository_provider.dart';
import 'package:forge/features/dashboard/data/mock/mock_dashboard_repository.dart';
import 'package:forge/features/dashboard/presentation/dashboard_page.dart';
import 'package:forge/features/missions/data/mock/mock_mission_context.dart';
import 'package:forge/features/missions/presentation/providers/mission_providers.dart';
import 'package:forge/shared/widgets/forge_button.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fake_auth_overrides.dart';
import '../../../support/fake_secure_key_value_store.dart';

void main() {
  Widget wrap({
    required DashboardMockScenario scenario,
    MockMissionContextScenario missionScenario =
        MockMissionContextScenario.normalActive,
    bool reduceMotion = false,
    double textScale = 1.0,
  }) {
    final router = GoRouter(
      initialLocation: AppRoutePaths.home,
      routes: [
        GoRoute(
          path: AppRoutePaths.home,
          name: AppRouteNames.home,
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: AppRoutePaths.rank,
          name: AppRouteNames.rank,
          builder: (context, state) => const Scaffold(body: Text('RANK STUB')),
        ),
        GoRoute(
          path: AppRoutePaths.progress,
          name: AppRouteNames.progress,
          builder: (context, state) =>
              const Scaffold(body: Text('PROGRESS STUB')),
        ),
        GoRoute(
          path: AppRoutePaths.awards,
          name: AppRouteNames.awards,
          builder: (context, state) =>
              const Scaffold(body: Text('AWARDS STUB')),
        ),
        GoRoute(
          path: AppRoutePaths.profile,
          name: AppRouteNames.profile,
          builder: (context, state) =>
              const Scaffold(body: Text('PROFILE STUB')),
        ),
        GoRoute(
          path: AppRoutePaths.dailyTransmission,
          name: AppRouteNames.dailyTransmission,
          builder: (context, state) =>
              const Scaffold(body: Text('TRANSMISSION STUB')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
        authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
        dashboardMockScenarioProvider.overrideWithValue(scenario),
        missionMockScenarioProvider.overrideWithValue(missionScenario),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp.router(
          theme: ForgeTheme.dark(),
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('loading state shows a spinner before the mock delay resolves', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(scenario: DashboardMockScenario.normalActive));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('normal dashboard shows header, mission, and league content', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(scenario: DashboardMockScenario.normalActive));
    await tester.pumpAndSettle();

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('10-Minute Full-Body Stretch'), findsOneWidget);
    expect(find.text('Iron League'), findsOneWidget);
  });

  testWidgets('new-user dashboard frames day 0 as a first mission', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        scenario: DashboardMockScenario.newUser,
        missionScenario: MockMissionContextScenario.firstDay,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review Five Flashcards'), findsOneWidget);
  });

  testWidgets(
    'recovery dashboard shows the recovery banner with non-shaming copy',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          scenario: DashboardMockScenario.recoveryMode,
          missionScenario: MockMissionContextScenario.recoveryMode,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recovery Mode'), findsOneWidget);
      expect(find.textContaining('rebuilding momentum'), findsOneWidget);
      expect(find.text('10-Minute Full-Body Stretch'), findsOneWidget);
      for (final phrase in ['failed', 'ruined', 'broke']) {
        expect(find.textContaining(phrase), findsNothing, reason: phrase);
      }
    },
  );

  testWidgets('completed-mission dashboard disables the primary action', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(scenario: DashboardMockScenario.completedMission),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<ForgeButton>(
      find.widgetWithText(ForgeButton, 'Completed'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'unrecoverable error shows the error state without a retry action',
    (tester) async {
      await tester.pumpWidget(
        wrap(scenario: DashboardMockScenario.repositoryError),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets('recoverable network error shows a retry action', (tester) async {
    await tester.pumpWidget(wrap(scenario: DashboardMockScenario.networkError));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your dashboard"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Tapping retry should not crash even though the underlying scenario
    // is unchanged (deeper retry-recovers-to-success coverage lives in
    // dashboard_notifier_test.dart).
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline without cache shows the offline state', (tester) async {
    await tester.pumpWidget(
      wrap(scenario: DashboardMockScenario.offlineNoCache),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're offline"), findsOneWidget);
  });

  testWidgets(
    'offline with cached data shows the populated dashboard plus a banner',
    (tester) async {
      await tester.pumpWidget(
        wrap(scenario: DashboardMockScenario.offlineCached),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('showing your last saved dashboard'),
        findsOneWidget,
      );
      expect(find.text('10-Minute Full-Body Stretch'), findsOneWidget);
    },
  );

  testWidgets('reduced motion skips the mission-frame reveal animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(scenario: DashboardMockScenario.normalActive, reduceMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('normal motion schedules the mission-frame reveal animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(scenario: DashboardMockScenario.normalActive, reduceMotion: false),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets('renders without overflow at a large text scale', (tester) async {
    await tester.pumpWidget(
      wrap(scenario: DashboardMockScenario.normalActive, textScale: 2.5),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the league card navigates to Rank', (tester) async {
    await tester.pumpWidget(wrap(scenario: DashboardMockScenario.normalActive));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(ForgeButton, 'View Rank');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('RANK STUB'), findsOneWidget);
  });

  testWidgets('a quick action navigates to Progress', (tester) async {
    await tester.pumpWidget(wrap(scenario: DashboardMockScenario.normalActive));
    await tester.pumpAndSettle();

    final action = find.text('Progress');
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('PROGRESS STUB'), findsOneWidget);
  });

  testWidgets('discipline progress exposes a semantic progress label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(wrap(scenario: DashboardMockScenario.normalActive));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(RegExp('Discipline progress: day 26 of 100')),
      findsOneWidget,
    );

    semantics.dispose();
  });

  group('Dashboard entrance (Roadmap Item 21)', () {
    testWidgets(
      'normal motion: content fades in (not immediately fully opaque) then '
      'settles to fully visible',
      (tester) async {
        await tester.pumpWidget(
          wrap(scenario: DashboardMockScenario.normalActive),
        );
        // Let the loading state resolve to DashboardPopulated, one frame in.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        final entranceFinder = find.byKey(
          const Key('dashboard-entrance-opacity'),
        );
        expect(entranceFinder, findsOneWidget);
        final midOpacity = tester.widget<Opacity>(entranceFinder).opacity;
        expect(
          midOpacity,
          lessThan(1.0),
          reason: 'expected an in-flight entrance fade below full opacity',
        );

        await tester.pumpAndSettle();

        // Once settled, the entrance either shows opacity 1.0 or has
        // removed itself entirely (both mean "fully visible").
        final settledFinder = find.byKey(
          const Key('dashboard-entrance-opacity'),
        );
        if (settledFinder.evaluate().isNotEmpty) {
          expect(tester.widget<Opacity>(settledFinder).opacity, 1.0);
        }
        expect(find.text('Test User'), findsOneWidget);
      },
    );

    testWidgets(
      'reduced motion: content is immediately fully visible, no fade-in '
      'window',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            scenario: DashboardMockScenario.normalActive,
            reduceMotion: true,
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        expect(find.text('Test User'), findsOneWidget);
        // Reduced motion returns widget.child directly (no Opacity
        // wrapper at all) — the entrance key must never appear.
        expect(
          find.byKey(const Key('dashboard-entrance-opacity')),
          findsNothing,
          reason: 'reduced motion must skip the fade entirely',
        );
      },
    );

    testWidgets(
      'does not replay on a data-only refresh of the same populated state',
      (tester) async {
        await tester.pumpWidget(
          wrap(scenario: DashboardMockScenario.normalActive),
        );
        await tester.pumpAndSettle();
        expect(find.text('Test User'), findsOneWidget);

        // A rebuild with the same DashboardPopulated case (no loading/error
        // state in between) must not reintroduce a mid-fade frame — the
        // entrance wrapper's State is preserved, not recreated.
        await tester.pump();
        final finder = find.byKey(const Key('dashboard-entrance-opacity'));
        if (finder.evaluate().isNotEmpty) {
          expect(tester.widget<Opacity>(finder).opacity, 1.0);
        }
      },
    );
  });
}
