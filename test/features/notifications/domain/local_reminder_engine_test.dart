import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/notifications/domain/entities/notification_preferences.dart';
import 'package:forge/features/notifications/domain/entities/quiet_hours.dart';
import 'package:forge/features/notifications/domain/services/local_reminder_engine.dart';

void main() {
  final noon = DateTime(2026, 8, 25, 12, 0);

  group('dailyMissionReminder', () {
    test('fires when the category is enabled, not shown today, and the '
        'mission is not yet accepted', () {
      final reminder = LocalReminderEngine.dailyMissionReminder(
        preferences: const NotificationPreferences(),
        localNow: noon,
        lastShownAt: null,
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionAlreadyAccepted: false,
      );
      expect(reminder, isNotNull);
      expect(reminder!.metadata['missionInstanceId'], 'mi-1');
      expect(reminder.metadata['missionTitle'], 'Push-ups');
    });

    test('is suppressed once the mission is already accepted', () {
      final reminder = LocalReminderEngine.dailyMissionReminder(
        preferences: const NotificationPreferences(),
        localNow: noon,
        lastShownAt: null,
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionAlreadyAccepted: true,
      );
      expect(reminder, isNull);
    });

    test('is suppressed if already shown earlier today (no repeat spam)', () {
      final reminder = LocalReminderEngine.dailyMissionReminder(
        preferences: const NotificationPreferences(),
        localNow: noon,
        lastShownAt: DateTime(2026, 8, 25, 8, 0),
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionAlreadyAccepted: false,
      );
      expect(reminder, isNull);
    });

    test('fires again on a new day even if shown yesterday', () {
      final reminder = LocalReminderEngine.dailyMissionReminder(
        preferences: const NotificationPreferences(),
        localNow: noon,
        lastShownAt: DateTime(2026, 8, 24, 8, 0),
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionAlreadyAccepted: false,
      );
      expect(reminder, isNotNull);
    });

    test('is suppressed when the master toggle is off', () {
      final reminder = LocalReminderEngine.dailyMissionReminder(
        preferences: const NotificationPreferences(masterEnabled: false),
        localNow: noon,
        lastShownAt: null,
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionAlreadyAccepted: false,
      );
      expect(reminder, isNull);
    });

    test('is suppressed when the category itself is disabled', () {
      final reminder = LocalReminderEngine.dailyMissionReminder(
        preferences: const NotificationPreferences(dailyMissionEnabled: false),
        localNow: noon,
        lastShownAt: null,
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionAlreadyAccepted: false,
      );
      expect(reminder, isNull);
    });

    test('is suppressed during quiet hours — event eligibility, not just '
        'delivery, is gated here since this reminder is never persisted', () {
      final reminder = LocalReminderEngine.dailyMissionReminder(
        preferences: const NotificationPreferences(
          quietHours: QuietHours(enabled: true, startMinute: 0, endMinute: 1439),
        ),
        localNow: noon,
        lastShownAt: null,
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionAlreadyAccepted: false,
      );
      expect(reminder, isNull);
    });

    test('dedup key is stable for the same day, regardless of exact minute', () {
      final a = LocalReminderEngine.dailyMissionReminder(
        preferences: const NotificationPreferences(),
        localNow: DateTime(2026, 8, 25, 9, 1),
        lastShownAt: null,
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionAlreadyAccepted: false,
      )!;
      final b = LocalReminderEngine.dailyMissionReminder(
        preferences: const NotificationPreferences(),
        localNow: DateTime(2026, 8, 25, 20, 45),
        lastShownAt: null,
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionAlreadyAccepted: false,
      )!;
      expect(a.dedupKey, b.dedupKey);
    });
  });

  group('dailyTransmissionReminder', () {
    test('fires when available and not yet accepted', () {
      final reminder = LocalReminderEngine.dailyTransmissionReminder(
        preferences: const NotificationPreferences(),
        localNow: noon,
        lastShownAt: null,
        transmissionAlreadyAvailableToUser: true,
        missionAlreadyAccepted: false,
      );
      expect(reminder, isNotNull);
    });

    test('does not fire when the transmission is not yet available', () {
      final reminder = LocalReminderEngine.dailyTransmissionReminder(
        preferences: const NotificationPreferences(),
        localNow: noon,
        lastShownAt: null,
        transmissionAlreadyAvailableToUser: false,
        missionAlreadyAccepted: false,
      );
      expect(reminder, isNull);
    });

    test('is suppressed once the mission has been accepted, since the '
        'transmission that revealed it necessarily already played', () {
      final reminder = LocalReminderEngine.dailyTransmissionReminder(
        preferences: const NotificationPreferences(),
        localNow: noon,
        lastShownAt: null,
        transmissionAlreadyAvailableToUser: true,
        missionAlreadyAccepted: true,
      );
      expect(reminder, isNull);
    });

    test('is suppressed by its own category toggle independently of the '
        'daily mission toggle', () {
      final reminder = LocalReminderEngine.dailyTransmissionReminder(
        preferences: const NotificationPreferences(dailyTransmissionEnabled: false),
        localNow: noon,
        lastShownAt: null,
        transmissionAlreadyAvailableToUser: true,
        missionAlreadyAccepted: false,
      );
      expect(reminder, isNull);
    });
  });

  group('missionFollowupReminder', () {
    final acceptedAt = DateTime(2026, 8, 25, 6, 0);

    test('never fires for an already-completed mission — the most '
        'important anti-nagging rule', () {
      final reminder = LocalReminderEngine.missionFollowupReminder(
        preferences: const NotificationPreferences(),
        localNow: acceptedAt.add(const Duration(hours: 8)),
        lastShownAt: null,
        acceptedAt: acceptedAt,
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionCompleted: true,
      );
      expect(reminder, isNull);
    });

    test('does not fire before the minimum age since acceptance', () {
      final reminder = LocalReminderEngine.missionFollowupReminder(
        preferences: const NotificationPreferences(),
        localNow: acceptedAt.add(const Duration(hours: 1)),
        lastShownAt: null,
        acceptedAt: acceptedAt,
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionCompleted: false,
      );
      expect(reminder, isNull);
    });

    test('fires once the minimum age has passed and never shown before', () {
      final reminder = LocalReminderEngine.missionFollowupReminder(
        preferences: const NotificationPreferences(),
        localNow: acceptedAt.add(const Duration(hours: 5)),
        lastShownAt: null,
        acceptedAt: acceptedAt,
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionCompleted: false,
      );
      expect(reminder, isNotNull);
    });

    test('respects the cooldown between two follow-ups for the same mission', () {
      final lastShown = acceptedAt.add(const Duration(hours: 5));
      final reminder = LocalReminderEngine.missionFollowupReminder(
        preferences: const NotificationPreferences(),
        localNow: lastShown.add(const Duration(hours: 2)),
        lastShownAt: lastShown,
        acceptedAt: acceptedAt,
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionCompleted: false,
      );
      expect(reminder, isNull, reason: 'still within the 6h cooldown');
    });

    test('fires again once the cooldown has fully elapsed', () {
      final lastShown = acceptedAt.add(const Duration(hours: 5));
      final reminder = LocalReminderEngine.missionFollowupReminder(
        preferences: const NotificationPreferences(),
        localNow: lastShown.add(const Duration(hours: 6, minutes: 1)),
        lastShownAt: lastShown,
        acceptedAt: acceptedAt,
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionCompleted: false,
      );
      expect(reminder, isNotNull);
    });

    test('dedup key is per mission instance, not per day, so it can '
        'legitimately recur while dedup still protects against exact retries', () {
      final reminder = LocalReminderEngine.missionFollowupReminder(
        preferences: const NotificationPreferences(),
        localNow: acceptedAt.add(const Duration(hours: 5)),
        lastShownAt: null,
        acceptedAt: acceptedAt,
        missionInstanceId: 'mi-42',
        missionTitle: 'Push-ups',
        missionCompleted: false,
      )!;
      expect(reminder.dedupKey, 'mission_followup:mi-42');
    });

    test('is suppressed by quiet hours even when otherwise eligible', () {
      final reminder = LocalReminderEngine.missionFollowupReminder(
        preferences: const NotificationPreferences(
          quietHours: QuietHours(enabled: true, startMinute: 0, endMinute: 1439),
        ),
        localNow: acceptedAt.add(const Duration(hours: 5)),
        lastShownAt: null,
        acceptedAt: acceptedAt,
        missionInstanceId: 'mi-1',
        missionTitle: 'Push-ups',
        missionCompleted: false,
      );
      expect(reminder, isNull);
    });
  });
}
