import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/notifications/domain/entities/forge_notification.dart';
import 'package:forge/features/notifications/domain/enums/forge_notification_type.dart';
import 'package:forge/features/notifications/domain/services/notification_copy.dart';

ForgeNotification _of(
  ForgeNotificationType type,
  Map<String, Object?> metadata,
) {
  return ForgeNotification(
    id: 'n',
    type: type,
    dedupKey: 'dedup',
    createdAt: DateTime(2026, 8, 20),
    readAt: null,
    metadata: metadata,
  );
}

void main() {
  test('resolve is total and deterministic — same input always produces the '
      'same title/body, no randomness or AI call involved', () {
    for (final type in ForgeNotificationType.values) {
      final notification = _of(type, const {});
      final first = NotificationCopy.resolve(notification);
      final second = NotificationCopy.resolve(notification);
      expect(first, second);
      expect(first.title, isNotEmpty);
      expect(first.body, isNotEmpty);
    }
  });

  test('achievement unlock copy uses the metadata title when present', () {
    final copy = NotificationCopy.resolve(
      _of(ForgeNotificationType.achievementUnlock, const {
        'title': 'First Steps',
      }),
    );
    expect(copy.title, 'Achievement unlocked');
    expect(copy.body, 'First Steps');
  });

  test('achievement unlock copy falls back gracefully with no metadata', () {
    final copy = NotificationCopy.resolve(
      _of(ForgeNotificationType.achievementUnlock, const {}),
    );
    expect(copy.body, isNotEmpty);
  });

  test('level up copy reflects the new level from metadata', () {
    final copy = NotificationCopy.resolve(
      _of(ForgeNotificationType.levelUp, const {'newLevel': 7}),
    );
    expect(copy.body, contains('7'));
  });

  test(
    'week result copy distinguishes promotion, demotion, and neutral zones',
    () {
      final promotion = NotificationCopy.resolve(
        _of(ForgeNotificationType.weekResult, const {
          'rank': 1,
          'promotionStatus': 'promotionZone',
        }),
      );
      final demotion = NotificationCopy.resolve(
        _of(ForgeNotificationType.weekResult, const {
          'rank': 10,
          'promotionStatus': 'demotionZone',
        }),
      );
      final neutral = NotificationCopy.resolve(
        _of(ForgeNotificationType.weekResult, const {
          'rank': 5,
          'promotionStatus': null,
        }),
      );

      expect(promotion.body, contains('promotion zone'));
      expect(demotion.body, contains('demotion zone'));
      expect(neutral.body, isNot(contains('zone')));
    },
  );

  test('season result copy distinguishes promoted, demoted, and neither', () {
    final promoted = NotificationCopy.resolve(
      _of(ForgeNotificationType.seasonResult, const {
        'promoted': true,
        'demoted': false,
      }),
    );
    final demoted = NotificationCopy.resolve(
      _of(ForgeNotificationType.seasonResult, const {
        'promoted': false,
        'demoted': true,
      }),
    );
    final neither = NotificationCopy.resolve(
      _of(ForgeNotificationType.seasonResult, const {
        'promoted': false,
        'demoted': false,
      }),
    );

    expect(promoted.body, contains('promoted'));
    expect(demoted.body, contains('moved down'));
    expect(neither.body, contains('final standing'));
  });

  test('weekly recap copy reflects active days from metadata', () {
    final copy = NotificationCopy.resolve(
      _of(ForgeNotificationType.weeklyRecap, const {'activeDays': 4}),
    );
    expect(copy.body, contains('4'));
  });

  test('no copy contains raw unresolved metadata keys or braces (a template '
      'that failed to substitute would leak these)', () {
    for (final type in ForgeNotificationType.values) {
      final copy = NotificationCopy.resolve(_of(type, const {}));
      expect(copy.title, isNot(contains('{')));
      expect(copy.body, isNot(contains('{')));
    }
  });
}
