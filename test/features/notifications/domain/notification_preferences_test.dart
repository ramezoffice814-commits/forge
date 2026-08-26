import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/notifications/domain/entities/notification_preferences.dart';
import 'package:forge/features/notifications/domain/entities/quiet_hours.dart';
import 'package:forge/features/notifications/domain/enums/forge_notification_type.dart';

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

  test(
    'copyWith changes only the requested field, leaving the rest intact',
    () {
      const preferences = NotificationPreferences();
      final updated = preferences.copyWith(masterEnabled: false);

      expect(updated.masterEnabled, isFalse);
      expect(updated.dailyMissionEnabled, isTrue);
      expect(updated.achievementEnabled, isTrue);
      expect(updated.reEngagementEnabled, isFalse);
    },
  );

  test('copyWith can replace quietHours and timezone together', () {
    const preferences = NotificationPreferences();
    final updated = preferences.copyWith(
      quietHours: const QuietHours(
        enabled: true,
        startMinute: 1320,
        endMinute: 360,
      ),
      timezone: 'Africa/Cairo',
    );

    expect(updated.quietHours.enabled, isTrue);
    expect(updated.quietHours.startMinute, 1320);
    expect(updated.timezone, 'Africa/Cairo');
    // Untouched fields still carry over.
    expect(updated.masterEnabled, isTrue);
  });

  test(
    'copyWith with no arguments returns an equivalent, independent value',
    () {
      const preferences = NotificationPreferences(
        masterEnabled: false,
        reEngagementEnabled: true,
      );
      final copy = preferences.copyWith();

      expect(copy.masterEnabled, isFalse);
      expect(copy.reEngagementEnabled, isTrue);
    },
  );

  group('allows', () {
    test('every type is allowed under the all-enabled defaults', () {
      const preferences = NotificationPreferences();
      for (final type in ForgeNotificationType.values) {
        expect(
          preferences.allows(type),
          isTrue,
          reason: '$type should be allowed by default',
        );
      }
    });

    test(
      'the master toggle overrides every category, even ones left enabled',
      () {
        const preferences = NotificationPreferences(masterEnabled: false);
        for (final type in ForgeNotificationType.values) {
          expect(
            preferences.allows(type),
            isFalse,
            reason: '$type must be blocked when master is off',
          );
        }
      },
    );

    test(
      'disabling a specific category blocks only that category\'s type(s)',
      () {
        const preferences = NotificationPreferences(achievementEnabled: false);
        expect(
          preferences.allows(ForgeNotificationType.achievementUnlock),
          isFalse,
        );
        expect(preferences.allows(ForgeNotificationType.levelUp), isTrue);
        expect(preferences.allows(ForgeNotificationType.weekResult), isTrue);
      },
    );

    test('competitionResultEnabled gates both week and season results', () {
      const preferences = NotificationPreferences(
        competitionResultEnabled: false,
      );
      expect(preferences.allows(ForgeNotificationType.weekResult), isFalse);
      expect(preferences.allows(ForgeNotificationType.seasonResult), isFalse);
      expect(
        preferences.allows(ForgeNotificationType.achievementUnlock),
        isTrue,
      );
    });

    test(
      'progressionEnabled gates level-up, independently of achievements',
      () {
        const preferences = NotificationPreferences(progressionEnabled: false);
        expect(preferences.allows(ForgeNotificationType.levelUp), isFalse);
        expect(
          preferences.allows(ForgeNotificationType.achievementUnlock),
          isTrue,
        );
      },
    );

    test('re-engagement stays opt-in even when everything else is on', () {
      const preferences = NotificationPreferences();
      // No re-engagement ForgeNotificationType exists yet (type H is not
      // implemented this pass) — this documents that reEngagementEnabled
      // has no `allows()` mapping to exercise, it is stored purely for
      // forward-compatibility with a future type.
      expect(preferences.reEngagementEnabled, isFalse);
    });
  });
}
