import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/notifications/domain/entities/notification_preferences.dart';
import 'package:forge/features/notifications/domain/entities/quiet_hours.dart';

void main() {
  test('defaults: every category is opt-out except re-engagement, which is '
      'opt-in — no manipulative come-back notification ever fires for a '
      'user who never touched settings', () {
    const preferences = NotificationPreferences();
    expect(preferences.masterEnabled, isTrue);
    expect(preferences.dailyMissionEnabled, isTrue);
    expect(preferences.dailyTransmissionEnabled, isTrue);
    expect(preferences.missionFollowupEnabled, isTrue);
    expect(preferences.achievementEnabled, isTrue);
    expect(preferences.progressionEnabled, isTrue);
    expect(preferences.weeklyRecapEnabled, isTrue);
    expect(preferences.competitionResultEnabled, isTrue);
    expect(preferences.reEngagementEnabled, isFalse);
    expect(preferences.quietHours.enabled, isFalse);
    expect(preferences.timezone, 'UTC');
  });

  test('copyWith changes only the requested field, leaving the rest intact', () {
    const preferences = NotificationPreferences();
    final updated = preferences.copyWith(masterEnabled: false);

    expect(updated.masterEnabled, isFalse);
    expect(updated.dailyMissionEnabled, isTrue);
    expect(updated.achievementEnabled, isTrue);
    expect(updated.reEngagementEnabled, isFalse);
  });

  test('copyWith can replace quietHours and timezone together', () {
    const preferences = NotificationPreferences();
    final updated = preferences.copyWith(
      quietHours: const QuietHours(enabled: true, startMinute: 1320, endMinute: 360),
      timezone: 'Africa/Cairo',
    );

    expect(updated.quietHours.enabled, isTrue);
    expect(updated.quietHours.startMinute, 1320);
    expect(updated.timezone, 'Africa/Cairo');
    // Untouched fields still carry over.
    expect(updated.masterEnabled, isTrue);
  });

  test('copyWith with no arguments returns an equivalent, independent value', () {
    const preferences = NotificationPreferences(masterEnabled: false, reEngagementEnabled: true);
    final copy = preferences.copyWith();

    expect(copy.masterEnabled, isFalse);
    expect(copy.reEngagementEnabled, isTrue);
  });
}
