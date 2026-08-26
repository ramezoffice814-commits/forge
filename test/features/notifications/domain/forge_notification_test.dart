import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/notifications/domain/entities/forge_notification.dart';
import 'package:forge/features/notifications/domain/enums/forge_notification_type.dart';
import 'package:forge/features/notifications/domain/enums/notification_priority.dart';

ForgeNotification _notification({DateTime? readAt}) {
  return ForgeNotification(
    id: 'n-1',
    type: ForgeNotificationType.levelUp,
    dedupKey: 'level_up:user-1:5',
    createdAt: DateTime(2026, 8, 20, 9),
    readAt: readAt,
    metadata: const {'newLevel': 5},
  );
}

void main() {
  test('isRead is false when readAt is null, true otherwise', () {
    expect(_notification().isRead, isFalse);
    expect(_notification(readAt: DateTime(2026, 8, 20, 10)).isRead, isTrue);
  });

  test(
    'copyWith(readAt: ...) marks it read without touching any other field',
    () {
      final original = _notification();
      final read = original.copyWith(readAt: DateTime(2026, 8, 21));

      expect(read.isRead, isTrue);
      expect(read.id, original.id);
      expect(read.type, original.type);
      expect(read.dedupKey, original.dedupKey);
      expect(read.createdAt, original.createdAt);
      expect(read.metadata, original.metadata);
      expect(read.priority, original.priority);
    },
  );

  test(
    'copyWith with no readAt argument preserves the existing read state',
    () {
      final alreadyRead = _notification(readAt: DateTime(2026, 8, 20, 10));
      final copy = alreadyRead.copyWith();
      expect(copy.readAt, alreadyRead.readAt);
    },
  );

  test('priority defaults to normal when not specified', () {
    expect(_notification().priority, NotificationPriority.normal);
  });
}
