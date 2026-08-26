import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/notifications/data/local_notification/local_notification_scheduler.dart';
import 'package:forge/features/notifications/domain/entities/forge_notification.dart';
import 'package:forge/features/notifications/domain/entities/quiet_hours.dart';
import 'package:forge/features/notifications/domain/enums/forge_notification_type.dart';
import 'package:forge/features/notifications/domain/services/local_reminder_engine.dart';

import '../../../../support/fake_local_notification_service.dart';

ForgeNotification _reminder(ForgeNotificationType type, String dedupKey) {
  return ForgeNotification(
    id: dedupKey,
    type: type,
    dedupKey: dedupKey,
    createdAt: DateTime(2026, 8, 25, 9, 0),
    readAt: null,
    metadata: const {},
  );
}

const _alwaysOpenQuietHours = QuietHours(
  enabled: false,
  startMinute: 1350,
  endMinute: 420,
);

void main() {
  group('stableId', () {
    test(
      'is deterministic — the same dedup key always maps to the same id',
      () {
        expect(
          LocalNotificationScheduler.stableId('daily_mission:2026-08-25'),
          LocalNotificationScheduler.stableId('daily_mission:2026-08-25'),
        );
      },
    );

    test('different dedup keys map to different ids (no accidental collision '
        'for the cases this app actually produces)', () {
      expect(
        LocalNotificationScheduler.stableId('daily_mission:2026-08-25'),
        isNot(
          LocalNotificationScheduler.stableId('daily_transmission:2026-08-25'),
        ),
      );
    });

    test('is always a non-negative int, never relying on a random source', () {
      for (final key in [
        'a',
        'mission_followup:abc-123',
        'daily_mission:2026-01-01',
      ]) {
        expect(
          LocalNotificationScheduler.stableId(key),
          greaterThanOrEqualTo(0),
        );
      }
    });
  });

  group('presentDueReminders', () {
    test('mirrors a due daily-mission/transmission reminder via showNow, '
        'keyed by its stable id', () async {
      final service = FakeLocalNotificationService();
      final scheduler = LocalNotificationScheduler(service);

      await scheduler.presentDueReminders([
        _reminder(
          ForgeNotificationType.dailyMission,
          'daily_mission:2026-08-25',
        ),
      ]);

      final id = LocalNotificationScheduler.stableId(
        'daily_mission:2026-08-25',
      );
      expect(service.shown.containsKey(id), isTrue);
      expect(
        service.shown[id]!.payload,
        ForgeNotificationType.dailyMission.wireName,
      );
    });

    test('never mirrors a mission-followup reminder via showNow — that type '
        'is exclusively owned by syncMissionFollowup\'s genuine scheduling, '
        'to avoid a double-fire', () async {
      final service = FakeLocalNotificationService();
      final scheduler = LocalNotificationScheduler(service);

      await scheduler.presentDueReminders([
        _reminder(
          ForgeNotificationType.missionFollowup,
          'mission_followup:abc',
        ),
      ]);

      expect(service.shown, isEmpty);
    });

    test('an empty list does nothing', () async {
      final service = FakeLocalNotificationService();
      final scheduler = LocalNotificationScheduler(service);
      await scheduler.presentDueReminders(const []);
      expect(service.shown, isEmpty);
    });
  });

  group('syncMissionFollowup', () {
    test(
      'schedules for acceptedAt + followupMinimumAge when eligible',
      () async {
        final service = FakeLocalNotificationService();
        final scheduler = LocalNotificationScheduler(service);
        final acceptedAt = DateTime(2026, 8, 25, 9, 0);

        await scheduler.syncMissionFollowup(
          missionInstanceId: 'inst-1',
          missionTitle: 'Push-ups',
          acceptedAt: acceptedAt,
          missionCompleted: false,
          categoryEnabled: true,
          masterEnabled: true,
          quietHours: _alwaysOpenQuietHours,
        );

        final id = LocalNotificationScheduler.stableId(
          'mission_followup:inst-1',
        );
        expect(service.scheduled.containsKey(id), isTrue);
        expect(
          service.scheduled[id]!.scheduledAt,
          acceptedAt.add(LocalReminderEngine.followupMinimumAge),
        );
        expect(
          service.scheduled[id]!.payload,
          ForgeNotificationType.missionFollowup.wireName,
        );
      },
    );

    test('defers the fire time out of quiet hours (spec section 9)', () async {
      final service = FakeLocalNotificationService();
      final scheduler = LocalNotificationScheduler(service);
      // Accepted at 19:00 -> naive due time is 23:00, squarely inside a
      // 22:30 -> 07:00 quiet window -> must defer to 07:00 the next day.
      final acceptedAt = DateTime(2026, 8, 25, 19, 0);

      await scheduler.syncMissionFollowup(
        missionInstanceId: 'inst-1',
        missionTitle: 'Push-ups',
        acceptedAt: acceptedAt,
        missionCompleted: false,
        categoryEnabled: true,
        masterEnabled: true,
        quietHours: const QuietHours(
          enabled: true,
          startMinute: 1350,
          endMinute: 420,
        ),
      );

      final id = LocalNotificationScheduler.stableId('mission_followup:inst-1');
      expect(service.scheduled[id]!.scheduledAt, DateTime(2026, 8, 26, 7, 0));
    });

    test('cancels the schedule once the mission is completed', () async {
      final service = FakeLocalNotificationService();
      final scheduler = LocalNotificationScheduler(service);
      final id = LocalNotificationScheduler.stableId('mission_followup:inst-1');

      await scheduler.syncMissionFollowup(
        missionInstanceId: 'inst-1',
        missionTitle: 'Push-ups',
        acceptedAt: DateTime(2026, 8, 25, 9, 0),
        missionCompleted: false,
        categoryEnabled: true,
        masterEnabled: true,
        quietHours: _alwaysOpenQuietHours,
      );
      expect(service.scheduled.containsKey(id), isTrue);

      await scheduler.syncMissionFollowup(
        missionInstanceId: 'inst-1',
        missionTitle: 'Push-ups',
        acceptedAt: DateTime(2026, 8, 25, 9, 0),
        missionCompleted: true,
        categoryEnabled: true,
        masterEnabled: true,
        quietHours: _alwaysOpenQuietHours,
      );

      expect(service.scheduled.containsKey(id), isFalse);
    });

    test('cancels when not yet accepted (acceptedAt is null)', () async {
      final service = FakeLocalNotificationService();
      final scheduler = LocalNotificationScheduler(service);

      await scheduler.syncMissionFollowup(
        missionInstanceId: 'inst-1',
        missionTitle: 'Push-ups',
        acceptedAt: null,
        missionCompleted: false,
        categoryEnabled: true,
        masterEnabled: true,
        quietHours: _alwaysOpenQuietHours,
      );

      final id = LocalNotificationScheduler.stableId('mission_followup:inst-1');
      expect(service.scheduled.containsKey(id), isFalse);
    });

    test('cancels when the category toggle is off', () async {
      final service = FakeLocalNotificationService();
      final scheduler = LocalNotificationScheduler(service);

      await scheduler.syncMissionFollowup(
        missionInstanceId: 'inst-1',
        missionTitle: 'Push-ups',
        acceptedAt: DateTime(2026, 8, 25, 9, 0),
        missionCompleted: false,
        categoryEnabled: false,
        masterEnabled: true,
        quietHours: _alwaysOpenQuietHours,
      );

      final id = LocalNotificationScheduler.stableId('mission_followup:inst-1');
      expect(service.scheduled.containsKey(id), isFalse);
    });

    test('cancels when the master toggle is off', () async {
      final service = FakeLocalNotificationService();
      final scheduler = LocalNotificationScheduler(service);

      await scheduler.syncMissionFollowup(
        missionInstanceId: 'inst-1',
        missionTitle: 'Push-ups',
        acceptedAt: DateTime(2026, 8, 25, 9, 0),
        missionCompleted: false,
        categoryEnabled: true,
        masterEnabled: false,
        quietHours: _alwaysOpenQuietHours,
      );

      final id = LocalNotificationScheduler.stableId('mission_followup:inst-1');
      expect(service.scheduled.containsKey(id), isFalse);
    });

    test('rescheduling with an updated acceptedAt replaces the prior '
        'schedule under the same stable id, never duplicating it', () async {
      final service = FakeLocalNotificationService();
      final scheduler = LocalNotificationScheduler(service);
      final id = LocalNotificationScheduler.stableId('mission_followup:inst-1');

      await scheduler.syncMissionFollowup(
        missionInstanceId: 'inst-1',
        missionTitle: 'Push-ups',
        acceptedAt: DateTime(2026, 8, 25, 9, 0),
        missionCompleted: false,
        categoryEnabled: true,
        masterEnabled: true,
        quietHours: _alwaysOpenQuietHours,
      );
      final firstFireTime = service.scheduled[id]!.scheduledAt;

      await scheduler.syncMissionFollowup(
        missionInstanceId: 'inst-1',
        missionTitle: 'Push-ups',
        acceptedAt: DateTime(2026, 8, 25, 10, 0),
        missionCompleted: false,
        categoryEnabled: true,
        masterEnabled: true,
        quietHours: _alwaysOpenQuietHours,
      );

      expect(service.scheduled.length, 1);
      expect(service.scheduled[id]!.scheduledAt, isNot(firstFireTime));
    });
  });

  group('cancelAllForSignOut', () {
    test('delegates to the service\'s cancelAll', () async {
      final service = FakeLocalNotificationService();
      final scheduler = LocalNotificationScheduler(service);
      await scheduler.cancelAllForSignOut();
      expect(service.cancelAllCalled, isTrue);
    });
  });
}
