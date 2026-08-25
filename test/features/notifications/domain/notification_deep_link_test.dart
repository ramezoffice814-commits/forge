import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/notifications/domain/enums/forge_notification_type.dart';
import 'package:forge/features/notifications/domain/enums/notification_deep_link.dart';

void main() {
  test('forType is total over every ForgeNotificationType — no type is ever '
      'left with an unmapped, arbitrary, or null-by-accident destination', () {
    for (final type in ForgeNotificationType.values) {
      expect(NotificationDeepLink.forType(type), isNotNull, reason: '$type has no deep link');
    }
  });

  test('every destination is one of the closed, allow-listed enum values', () {
    for (final type in ForgeNotificationType.values) {
      expect(NotificationDeepLink.forType(type), isA<NotificationDeepLink>());
    }
  });

  test('routes each type to its expected, reviewed destination', () {
    expect(
      NotificationDeepLink.forType(ForgeNotificationType.dailyMission),
      NotificationDeepLink.activeMission,
    );
    expect(
      NotificationDeepLink.forType(ForgeNotificationType.dailyTransmission),
      NotificationDeepLink.dailyTransmission,
    );
    expect(
      NotificationDeepLink.forType(ForgeNotificationType.missionFollowup),
      NotificationDeepLink.activeMission,
    );
    expect(
      NotificationDeepLink.forType(ForgeNotificationType.achievementUnlock),
      NotificationDeepLink.progression,
    );
    expect(
      NotificationDeepLink.forType(ForgeNotificationType.levelUp),
      NotificationDeepLink.progression,
    );
    expect(
      NotificationDeepLink.forType(ForgeNotificationType.weekResult),
      NotificationDeepLink.leaderboard,
    );
    expect(
      NotificationDeepLink.forType(ForgeNotificationType.seasonResult),
      NotificationDeepLink.leaderboard,
    );
    expect(
      NotificationDeepLink.forType(ForgeNotificationType.weeklyRecap),
      NotificationDeepLink.progression,
    );
  });
}
