/// The complete, closed set of destinations a notification is ever
/// allowed to route to (Roadmap Item 15 section 12) — mirrors
/// `AiCoachSuggestedAction`'s "the enum IS the authority boundary"
/// pattern exactly. There is no constructor path from a raw
/// server-supplied `type` string to app navigation that skips this;
/// [forDeepLink] is the only place a [ForgeNotificationType] is ever
/// turned into a route, and an unrecognized type fails safe (returns
/// null — the caller does nothing, never navigates to an arbitrary or
/// default location).
library;

import '../enums/forge_notification_type.dart';

enum NotificationDeepLink {
  dashboard,
  dailyTransmission,
  activeMission,
  progression,
  leaderboard;

  static NotificationDeepLink? forType(ForgeNotificationType type) => switch (type) {
    ForgeNotificationType.dailyMission => activeMission,
    ForgeNotificationType.dailyTransmission => dailyTransmission,
    ForgeNotificationType.missionFollowup => activeMission,
    ForgeNotificationType.achievementUnlock => progression,
    ForgeNotificationType.levelUp => progression,
    ForgeNotificationType.weekResult => leaderboard,
    ForgeNotificationType.seasonResult => leaderboard,
    ForgeNotificationType.weeklyRecap => progression,
  };
}
