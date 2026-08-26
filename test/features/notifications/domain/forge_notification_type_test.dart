import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/notifications/domain/enums/forge_notification_type.dart';

void main() {
  test('wireName is total and matches the SQL check constraint\'s snake_case '
      'values exactly', () {
    expect(ForgeNotificationType.dailyMission.wireName, 'daily_mission');
    expect(
      ForgeNotificationType.dailyTransmission.wireName,
      'daily_transmission',
    );
    expect(ForgeNotificationType.missionFollowup.wireName, 'mission_followup');
    expect(
      ForgeNotificationType.achievementUnlock.wireName,
      'achievement_unlock',
    );
    expect(ForgeNotificationType.levelUp.wireName, 'level_up');
    expect(ForgeNotificationType.weekResult.wireName, 'week_result');
    expect(ForgeNotificationType.seasonResult.wireName, 'season_result');
    expect(ForgeNotificationType.weeklyRecap.wireName, 'weekly_recap');
  });

  test('tryParse round-trips every value through its own wireName', () {
    for (final type in ForgeNotificationType.values) {
      expect(ForgeNotificationType.tryParse(type.wireName), type);
    }
  });

  test('tryParse never guesses on an unknown or malformed string', () {
    expect(ForgeNotificationType.tryParse('achievementUnlock'), isNull);
    expect(ForgeNotificationType.tryParse('grant_xp'), isNull);
    expect(ForgeNotificationType.tryParse(''), isNull);
    expect(ForgeNotificationType.tryParse('DAILY_MISSION'), isNull);
  });

  test('isServerAuthoritative matches the trust-boundary split exactly', () {
    const clientOwned = {
      ForgeNotificationType.dailyMission,
      ForgeNotificationType.dailyTransmission,
      ForgeNotificationType.missionFollowup,
    };
    const serverAuthoritative = {
      ForgeNotificationType.achievementUnlock,
      ForgeNotificationType.levelUp,
      ForgeNotificationType.weekResult,
      ForgeNotificationType.seasonResult,
      ForgeNotificationType.weeklyRecap,
    };
    for (final type in clientOwned) {
      expect(
        type.isServerAuthoritative,
        isFalse,
        reason: '$type must be client-owned',
      );
    }
    for (final type in serverAuthoritative) {
      expect(
        type.isServerAuthoritative,
        isTrue,
        reason: '$type must be server-authoritative',
      );
    }
    expect(
      clientOwned.length + serverAuthoritative.length,
      ForgeNotificationType.values.length,
    );
  });
}
