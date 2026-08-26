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
