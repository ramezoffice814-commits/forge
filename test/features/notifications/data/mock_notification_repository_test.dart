import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/notifications/data/mock/mock_notification_repository.dart';
import 'package:forge/features/notifications/domain/entities/forge_notification.dart';
import 'package:forge/features/notifications/domain/enums/forge_notification_type.dart';

ForgeNotification _seed(String id, DateTime createdAt, {DateTime? readAt}) {
  return ForgeNotification(
    id: id,
    type: ForgeNotificationType.levelUp,
    dedupKey: 'level_up:$id',
    createdAt: createdAt,
    readAt: readAt,
    metadata: const {},
  );
}

void main() {
  test('fetchInbox returns notifications newest-first', () async {
    final repository = MockNotificationRepository(
      seed: [
        _seed('a', DateTime(2026, 8, 20)),
        _seed('b', DateTime(2026, 8, 22)),
        _seed('c', DateTime(2026, 8, 21)),
      ],
    );

    final inbox = await repository.fetchInbox();
    expect(inbox.map((n) => n.id).toList(), ['b', 'c', 'a']);
  });

  test('markRead flips only the targeted notification\'s read state', () async {
    final repository = MockNotificationRepository(
      seed: [_seed('a', DateTime(2026, 8, 20)), _seed('b', DateTime(2026, 8, 21))],
    );

    await repository.markRead('a');
    final inbox = await repository.fetchInbox();

    expect(inbox.firstWhere((n) => n.id == 'a').isRead, isTrue);
    expect(inbox.firstWhere((n) => n.id == 'b').isRead, isFalse);
  });

  test('markRead on an unknown id is a safe no-op', () async {
    final repository = MockNotificationRepository(seed: [_seed('a', DateTime(2026, 8, 20))]);
    await repository.markRead('does-not-exist');
    final inbox = await repository.fetchInbox();
    expect(inbox.single.isRead, isFalse);
  });

  test('markAllRead marks every unread notification read and leaves already-read '
      'ones untouched', () async {
    final alreadyReadAt = DateTime(2026, 8, 19);
    final repository = MockNotificationRepository(
      seed: [
        _seed('a', DateTime(2026, 8, 20)),
        _seed('b', DateTime(2026, 8, 21), readAt: alreadyReadAt),
      ],
    );

    await repository.markAllRead();
    final inbox = await repository.fetchInbox();

    expect(inbox.every((n) => n.isRead), isTrue);
    expect(inbox.firstWhere((n) => n.id == 'b').readAt, alreadyReadAt);
  });

  test('preferences default, then persist via updatePreferences/getPreferences', () async {
    final repository = MockNotificationRepository();
    final defaults = await repository.getPreferences();
    expect(defaults.masterEnabled, isTrue);

    final updated = defaults.copyWith(masterEnabled: false);
    await repository.updatePreferences(updated);

    final reloaded = await repository.getPreferences();
    expect(reloaded.masterEnabled, isFalse);
  });
}
