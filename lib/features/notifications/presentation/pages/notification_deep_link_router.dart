import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../missions/presentation/providers/resolved_mission_instance_controller.dart';
import '../../domain/enums/notification_deep_link.dart';

/// The only place a [NotificationDeepLink] becomes a real navigation
/// call (Roadmap Item 15 section 12) — every branch uses an existing
/// named route exactly as ordinary in-app navigation already does
/// (`TodayMissionCard`'s own `context.pushNamed`/`goNamed` calls), never
/// a route string built from notification payload data. [activeMission]
/// specifically re-resolves the *current* authoritative mission via
/// [resolvedMissionInstanceProvider] rather than trusting any mission id
/// a notification's metadata might carry — a stale or forged id in a
/// payload can therefore never route anywhere but here, and even here
/// it's ignored outright.
void navigateToDeepLink(
  BuildContext context,
  WidgetRef ref,
  NotificationDeepLink destination,
) {
  switch (destination) {
    case NotificationDeepLink.dashboard:
      context.goNamed(AppRouteNames.home);
    case NotificationDeepLink.dailyTransmission:
      context.pushNamed(AppRouteNames.dailyTransmission);
    case NotificationDeepLink.activeMission:
      final resolved = ref.read(resolvedMissionInstanceProvider);
      if (resolved == null) {
        // No authoritative mission to show right now — fails safe to
        // the dashboard rather than a broken/parameterless route.
        context.goNamed(AppRouteNames.home);
        return;
      }
      context.pushNamed(
        AppRouteNames.activeMission,
        pathParameters: {'missionInstanceId': resolved.instance.instanceId},
      );
    case NotificationDeepLink.progression:
      context.goNamed(AppRouteNames.progress);
    case NotificationDeepLink.leaderboard:
      context.goNamed(AppRouteNames.rank);
  }
}

/// Same routing table as [navigateToDeepLink], for a caller with no
/// [BuildContext] under a `GoRouter` ancestor — an OS notification tap
/// (Roadmap Item 17) can fire before any screen is mounted (cold start)
/// or from a plugin callback outside the widget tree entirely.
/// [GoRouter.goNamed]/[pushNamed] are plain instance methods that don't
/// need a `BuildContext` (unlike the `context.goNamed` extension, which
/// only exists to look one up via `GoRouter.of(context)`), so this
/// operates on the router object directly. [read] is deliberately typed
/// as the shared generic signature `Ref.read`/`WidgetRef.read`/
/// `ProviderContainer.read` all share, rather than any one of those
/// concrete types, so this works from a provider (pass `ref.read`) or a
/// test harness holding a bare `ProviderContainer` (pass
/// `container.read`) alike. Deliberately a second switch rather than a
/// shared helper — [NotificationDeepLink] is a closed, exhaustive enum,
/// so the compiler itself keeps both switches from silently drifting
/// apart if a new variant is ever added.
void navigateToDeepLinkWithRouter(
  GoRouter router,
  T Function<T>(ProviderListenable<T> provider) read,
  NotificationDeepLink destination,
) {
  switch (destination) {
    case NotificationDeepLink.dashboard:
      router.goNamed(AppRouteNames.home);
    case NotificationDeepLink.dailyTransmission:
      router.pushNamed(AppRouteNames.dailyTransmission);
    case NotificationDeepLink.activeMission:
      final resolved = read(resolvedMissionInstanceProvider);
      if (resolved == null) {
        router.goNamed(AppRouteNames.home);
        return;
      }
      router.pushNamed(
        AppRouteNames.activeMission,
        pathParameters: {'missionInstanceId': resolved.instance.instanceId},
      );
    case NotificationDeepLink.progression:
      router.goNamed(AppRouteNames.progress);
    case NotificationDeepLink.leaderboard:
      router.goNamed(AppRouteNames.rank);
  }
}
