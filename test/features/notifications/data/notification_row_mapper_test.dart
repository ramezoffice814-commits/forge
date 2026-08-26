import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/notifications/data/supabase/notification_row_mapper.dart';
import 'package:forge/features/notifications/domain/entities/notification_preferences.dart';
import 'package:forge/features/notifications/domain/enums/forge_notification_type.dart';

void main() {
  group('parseNotificationRow', () {
    test('parses a well-formed server row into a ForgeNotification', () {
      final notification = parseNotificationRow({
        'id': 'row-1',
        'type': 'achievement_unlock',
        'dedup_key': 'achievement:user-1:ach-1',
        'created_at': '2026-08-20T09:00:00.000Z',
        'read_at': null,
        'metadata': {'achievementId': 'ach-1', 'title': 'First Steps'},
      });

      expect(notification, isNotNull);
      expect(notification!.id, 'row-1');
      expect(notification.type, ForgeNotificationType.achievementUnlock);
      expect(notification.dedupKey, 'achievement:user-1:ach-1');
      expect(notification.isRead, isFalse);
      expect(notification.metadata['title'], 'First Steps');
    });

    test('parses a read row with a non-null read_at', () {
      final notification = parseNotificationRow({
        'id': 'row-2',
        'type': 'level_up',
        'dedup_key': 'level_up:user-1:5',
        'created_at': '2026-08-20T09:00:00.000Z',
        'read_at': '2026-08-21T09:00:00.000Z',
        'metadata': <String, dynamic>{},
      });

      expect(notification!.isRead, isTrue);
    });

    test('returns null for an unrecognized type rather than throwing — '
        'forward compatible with a server that knows a newer type', () {
      final notification = parseNotificationRow({
        'id': 'row-3',
        'type': 'some_future_type',
        'dedup_key': 'x',
        'created_at': '2026-08-20T09:00:00.000Z',
        'read_at': null,
        'metadata': <String, dynamic>{},
      });
      expect(notification, isNull);
    });

    test('returns null for a missing/blank type string', () {
      final notification = parseNotificationRow({
        'id': 'row-4',
        'dedup_key': 'x',
        'created_at': '2026-08-20T09:00:00.000Z',
        'read_at': null,
        'metadata': <String, dynamic>{},
      });
      expect(notification, isNull);
    });

    test(
      'defaults metadata to an empty map when the row value is not a map',
      () {
        final notification = parseNotificationRow({
          'id': 'row-5',
          'type': 'weekly_recap',
          'dedup_key': 'x',
          'created_at': '2026-08-20T09:00:00.000Z',
          'read_at': null,
          'metadata': 'not-a-map',
        });
        expect(notification!.metadata, isEmpty);
      },
    );
  });

  group('parsePreferencesRow / preferencesToRow round trip', () {
    test('round-trips a fully customized preferences object', () {
      const preferences = NotificationPreferences(
        masterEnabled: false,
        dailyMissionEnabled: false,
        achievementEnabled: true,
        reEngagementEnabled: true,
        timezone: 'Africa/Cairo',
      );

      final row = preferencesToRow(preferences);
      final roundTripped = parsePreferencesRow(row);

      expect(roundTripped.masterEnabled, preferences.masterEnabled);
      expect(roundTripped.dailyMissionEnabled, preferences.dailyMissionEnabled);
      expect(roundTripped.achievementEnabled, preferences.achievementEnabled);
      expect(roundTripped.reEngagementEnabled, preferences.reEngagementEnabled);
      expect(roundTripped.timezone, preferences.timezone);
      expect(roundTripped.quietHours.enabled, preferences.quietHours.enabled);
      expect(
        roundTripped.quietHours.startMinute,
        preferences.quietHours.startMinute,
      );
      expect(
        roundTripped.quietHours.endMinute,
        preferences.quietHours.endMinute,
      );
    });

    test('parsePreferencesRow defaults missing columns to the safe defaults, '
        'never throwing on a partial row', () {
      final preferences = parsePreferencesRow(const {});
      expect(preferences.masterEnabled, isTrue);
      expect(preferences.reEngagementEnabled, isFalse);
      expect(preferences.timezone, 'UTC');
    });
  });
}
