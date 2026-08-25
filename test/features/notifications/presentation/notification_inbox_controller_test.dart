import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/missions/presentation/providers/mission_lifecycle_controller.dart';
import 'package:forge/features/missions/presentation/providers/resolved_mission_instance_controller.dart';
import 'package:forge/features/notifications/data/mock/mock_notification_repository.dart';
import 'package:forge/features/notifications/domain/entities/forge_notification.dart';
import 'package:forge/features/notifications/domain/entities/notification_preferences.dart';
import 'package:forge/features/notifications/domain/enums/forge_notification_type.dart';
import 'package:forge/features/notifications/presentation/providers/notification_inbox_controller.dart';
import 'package:forge/features/notifications/presentation/providers/notification_inbox_state.dart';
import 'package:forge/features/notifications/presentation/providers/notification_preferences_controller.dart';
import 'package:forge/features/notifications/presentation/providers/notification_providers.dart';

import '../../../support/fake_auth_overrides.dart';
import '../../../support/fake_secure_key_value_store.dart';

ForgeNotification _serverNotification(String id, DateTime createdAt, {DateTime? readAt}) {
  return ForgeNotification(
    id: id,
    type: ForgeNotificationType.levelUp,
    dedupKey: 'level_up:$id',
    createdAt: createdAt,
    readAt: readAt,
    metadata: const {},
  );
}

List<Override> _baseOverrides(MockNotificationRepository repository) => [
  ...authenticatedTestOverrides(),
  secureKeyValueStoreProvider.overrideWithValue(FakeSecureKeyValueStore()),
  notificationRepositoryProvider.overrideWithValue(repository),
];

Future<String> _readyMissionInstanceId(ProviderContainer container) async {
  await container.read(resolvedMissionInstanceControllerProvider.notifier).ready;
  return container.read(resolvedMissionInstanceProvider)!.instance.instanceId;
}

void main() {
  test('an unauthenticated session never surfaces a previous session\'s '
      'notifications — stays Loading rather than leaking state', () async {
    final container = ProviderContainer(
      overrides: [
        authStateNotifierProvider.overrideWith(FakeUnauthenticatedNotifier.new),
        secureKeyValueStoreProvider.overrideWithValue(FakeSecureKeyValueStore()),
        notificationRepositoryProvider.overrideWithValue(MockNotificationRepository()),
      ],
    );
    addTearDown(container.dispose);

    await Future<void>.delayed(Duration.zero);
    expect(container.read(notificationInboxControllerProvider), isA<NotificationInboxLoading>());
  });

  test('merges server-authoritative notifications with client-owned local '
      'reminders into one newest-first list', () async {
    final repository = MockNotificationRepository(
      seed: [_serverNotification('lvl-1', DateTime(2000, 1, 1))],
    );
    final container = ProviderContainer(overrides: _baseOverrides(repository));
    addTearDown(container.dispose);

    // The inbox controller's own `_load()` reads `resolvedMissionInstanceProvider`
    // synchronously — it must already be resolved (not mid-flight) for the
    // client-owned local reminder to be computed rather than skipped.
    await container.read(resolvedMissionInstanceControllerProvider.notifier).ready;
    await container.read(notificationInboxControllerProvider.notifier).ready;
    final state = container.read(notificationInboxControllerProvider) as NotificationInboxReady;

    // The mock mission starts freshly assigned (not yet accepted), so the
    // daily-mission local reminder is expected to fire and, being
    // "now", sorts ahead of the old server row.
    expect(state.notifications.first.type, ForgeNotificationType.dailyMission);
    expect(state.notifications.any((n) => n.id == 'lvl-1'), isTrue);
  });

  test('markRead updates local state immediately and calls the repository '
      'only for the server-authoritative notification, never for a local '
      'reminder', () async {
    final repository = MockNotificationRepository(
      seed: [_serverNotification('lvl-1', DateTime(2020, 1, 1))],
    );
    final container = ProviderContainer(overrides: _baseOverrides(repository));
    addTearDown(container.dispose);

    await container.read(notificationInboxControllerProvider.notifier).ready;
    var state = container.read(notificationInboxControllerProvider) as NotificationInboxReady;
    final serverNotification = state.notifications.firstWhere((n) => n.id == 'lvl-1');
    expect(serverNotification.isRead, isFalse);

    await container.read(notificationInboxControllerProvider.notifier).markRead(serverNotification);

    state = container.read(notificationInboxControllerProvider) as NotificationInboxReady;
    expect(state.notifications.firstWhere((n) => n.id == 'lvl-1').isRead, isTrue);

    final persisted = await repository.fetchInbox();
    expect(persisted.single.isRead, isTrue);
  });

  test('markAllRead marks every notification read in local state and '
      'persists the server-side ones', () async {
    final repository = MockNotificationRepository(
      seed: [
        _serverNotification('lvl-1', DateTime(2020, 1, 1)),
        _serverNotification('lvl-2', DateTime(2020, 1, 2)),
      ],
    );
    final container = ProviderContainer(overrides: _baseOverrides(repository));
    addTearDown(container.dispose);

    await container.read(notificationInboxControllerProvider.notifier).ready;
    await container.read(notificationInboxControllerProvider.notifier).markAllRead();

    final state = container.read(notificationInboxControllerProvider) as NotificationInboxReady;
    expect(state.notifications.every((n) => n.isRead), isTrue);

    final persisted = await repository.fetchInbox();
    expect(persisted.every((n) => n.isRead), isTrue);
  });

  test('unreadCount reflects only unread notifications, server and local '
      'combined', () async {
    final repository = MockNotificationRepository(
      seed: [
        _serverNotification('lvl-1', DateTime(2020, 1, 1)),
        _serverNotification('lvl-2', DateTime(2020, 1, 2), readAt: DateTime(2020, 1, 3)),
      ],
    );
    final container = ProviderContainer(overrides: _baseOverrides(repository));
    addTearDown(container.dispose);

    await container.read(resolvedMissionInstanceControllerProvider.notifier).ready;
    await container.read(notificationInboxControllerProvider.notifier).ready;
    final state = container.read(notificationInboxControllerProvider) as NotificationInboxReady;

    // 1 unread server row (lvl-1) + the daily-mission and daily-transmission
    // local reminders (fresh, unaccepted mission, neither shown before) = 3.
    expect(state.unreadCount, 3);
  });

  test('once the mission is accepted, the daily-mission local reminder no '
      'longer appears in the inbox', () async {
    final repository = MockNotificationRepository();
    final container = ProviderContainer(overrides: _baseOverrides(repository));
    addTearDown(container.dispose);

    final instanceId = await _readyMissionInstanceId(container);
    await container.read(missionLifecycleControllerProvider(instanceId).notifier).accept();

    await container.read(notificationInboxControllerProvider.notifier).ready;
    final state = container.read(notificationInboxControllerProvider) as NotificationInboxReady;

    expect(state.notifications.any((n) => n.type == ForgeNotificationType.dailyMission), isFalse);
  });

  test('a disabled category is filtered out of the inbox entirely — a '
      'server-authoritative row still exists, but must not be shown to a '
      'user who opted out of that category', () async {
    final repository = MockNotificationRepository(
      seed: [_serverNotification('lvl-1', DateTime(2020, 1, 1))],
    );
    await repository.updatePreferences(const NotificationPreferences(progressionEnabled: false));
    final container = ProviderContainer(overrides: _baseOverrides(repository));
    addTearDown(container.dispose);

    await container.read(notificationInboxControllerProvider.notifier).ready;
    final state = container.read(notificationInboxControllerProvider) as NotificationInboxReady;

    expect(state.notifications.any((n) => n.id == 'lvl-1'), isFalse);
  });

  test('the master toggle hides every server-authoritative notification, '
      'not just one category', () async {
    final repository = MockNotificationRepository(
      seed: [_serverNotification('lvl-1', DateTime(2020, 1, 1))],
    );
    await repository.updatePreferences(const NotificationPreferences(masterEnabled: false));
    final container = ProviderContainer(overrides: _baseOverrides(repository));
    addTearDown(container.dispose);

    await container.read(notificationInboxControllerProvider.notifier).ready;
    final state = container.read(notificationInboxControllerProvider) as NotificationInboxReady;

    expect(state.notifications, isEmpty);
  });

  test('changing a preference while the inbox is already loaded re-filters '
      'it immediately, without requiring the user to navigate away and '
      'back', () async {
    final repository = MockNotificationRepository(
      seed: [_serverNotification('lvl-1', DateTime(2020, 1, 1))],
    );
    final container = ProviderContainer(overrides: _baseOverrides(repository));
    addTearDown(container.dispose);

    await container.read(notificationInboxControllerProvider.notifier).ready;
    var state = container.read(notificationInboxControllerProvider) as NotificationInboxReady;
    expect(state.notifications.any((n) => n.id == 'lvl-1'), isTrue);

    await container
        .read(notificationPreferencesControllerProvider.notifier)
        .update(const NotificationPreferences(progressionEnabled: false));

    // The reactive rebuild's own `_load()` is a fresh async task with no
    // new `ready` signal of its own to await (the controller's `ready`
    // completer already resolved from the first load) — poll a bounded
    // number of microtask turns instead of asserting on a fixed delay.
    NotificationInboxReady? refiltered;
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(Duration.zero);
      final current = container.read(notificationInboxControllerProvider);
      if (current is NotificationInboxReady && !current.notifications.any((n) => n.id == 'lvl-1')) {
        refiltered = current;
        break;
      }
    }

    expect(refiltered, isNotNull, reason: 'inbox was never re-filtered after the preference change');
  });
}
