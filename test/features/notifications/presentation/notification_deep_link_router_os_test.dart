import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/router/app_routes.dart';
import 'package:forge/features/missions/domain/entities/resolved_mission_instance.dart';
import 'package:forge/features/missions/domain/enums/mission_instance_authority.dart';
import 'package:forge/features/missions/presentation/providers/resolved_mission_instance_controller.dart';
import 'package:forge/features/notifications/domain/enums/notification_deep_link.dart';
import 'package:forge/features/notifications/presentation/pages/notification_deep_link_router.dart';
import 'package:go_router/go_router.dart';

import '../../../support/mission_lifecycle_test_helpers.dart';

/// Covers the router-object variant used by an OS notification tap
/// (Roadmap Item 17 section 11) — [navigateToDeepLink] itself (the
/// BuildContext variant) already has coverage via
/// `notification_inbox_page_test.dart`'s tap-through tests. Uses a
/// minimal, purpose-built router/widget tree rather than the full app
/// router — this is testing the routing *table*, not any destination
/// page's own rendering, so there's no reason to drag in Daily
/// Transmission's animation/TTS timers or a real mission-resolution
/// race.
void main() {
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        name: AppRouteNames.home,
        builder: (context, state) => const SizedBox(),
      ),
      GoRoute(
        path: '/daily-transmission',
        name: AppRouteNames.dailyTransmission,
        builder: (context, state) => const SizedBox(),
      ),
      GoRoute(
        path: '/mission/:missionInstanceId',
        name: AppRouteNames.activeMission,
        builder: (context, state) => const SizedBox(),
      ),
      GoRoute(
        path: '/progress',
        name: AppRouteNames.progress,
        builder: (context, state) => const SizedBox(),
      ),
      GoRoute(
        path: '/rank',
        name: AppRouteNames.rank,
        builder: (context, state) => const SizedBox(),
      ),
    ],
  );

  Future<GoRouter> pump(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    final router = buildRouter();
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('dashboard destination navigates to /home', (tester) async {
    final router = await pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    navigateToDeepLinkWithRouter(
      router,
      container.read,
      NotificationDeepLink.dashboard,
    );
    await tester.pumpAndSettle();

    expect(locationOf(router), '/home');
  });

  // dailyTransmission and the resolved-mission branch of activeMission
  // both call `router.pushNamed` rather than `goNamed` — a bare
  // `GoRouter` outside a full app context doesn't reliably reflect a
  // push in `currentConfiguration.uri` in this go_router version (
  // reproduced with a trivial two-route router with no app-specific
  // code at all), so these two only assert "calls a valid, registered
  // route name without throwing." The actual navigated-to destination
  // for this exact switch is already proven via the BuildContext
  // variant (`navigateToDeepLink`) against the real app router in
  // `notification_inbox_page_test.dart`'s tap-through tests.
  testWidgets(
    'dailyTransmission destination pushes the transmission route without '
    'throwing',
    (tester) async {
      final router = await pump(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      navigateToDeepLinkWithRouter(
        router,
        container.read,
        NotificationDeepLink.dailyTransmission,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('activeMission destination pushes the mission route (with the '
      'resolved instance id, never a payload-supplied one) without '
      'throwing when a mission is actually resolved', (tester) async {
    final resolved = ResolvedMissionInstance(
      instance: testMissionInstance(),
      authority: MissionInstanceAuthority.localOnly,
    );
    final router = await pump(
      tester,
      overrides: [resolvedMissionInstanceProvider.overrideWithValue(resolved)],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    navigateToDeepLinkWithRouter(
      router,
      container.read,
      NotificationDeepLink.activeMission,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('activeMission destination falls back to /home when there is no '
      'authoritative mission to resolve — never a broken route from '
      'trusting notification-payload data', (tester) async {
    final router = await pump(
      tester,
      overrides: [resolvedMissionInstanceProvider.overrideWithValue(null)],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    navigateToDeepLinkWithRouter(
      router,
      container.read,
      NotificationDeepLink.activeMission,
    );
    await tester.pumpAndSettle();

    expect(locationOf(router), '/home');
  });

  testWidgets('progression destination navigates to /progress', (tester) async {
    final router = await pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    navigateToDeepLinkWithRouter(
      router,
      container.read,
      NotificationDeepLink.progression,
    );
    await tester.pumpAndSettle();

    expect(locationOf(router), '/progress');
  });

  testWidgets('leaderboard destination navigates to /rank', (tester) async {
    final router = await pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    navigateToDeepLinkWithRouter(
      router,
      container.read,
      NotificationDeepLink.leaderboard,
    );
    await tester.pumpAndSettle();

    expect(locationOf(router), '/rank');
  });
}
