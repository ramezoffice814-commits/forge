import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/features/auth/presentation/auth_state.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/missions/presentation/providers/mission_lifecycle_controller.dart';
import 'package:forge/features/missions/presentation/providers/resolved_mission_instance_controller.dart';
import 'package:forge/features/notifications/data/local_notification/local_notification_scheduler.dart';
import 'package:forge/features/notifications/data/mock/mock_notification_repository.dart';
import 'package:forge/features/notifications/domain/entities/forge_notification.dart';
import 'package:forge/features/notifications/domain/entities/notification_preferences.dart';
import 'package:forge/features/notifications/domain/enums/forge_notification_type.dart';
import 'package:forge/features/notifications/domain/repositories/notification_repository.dart';
import 'package:forge/features/notifications/presentation/providers/notification_inbox_controller.dart';
import 'package:forge/features/notifications/presentation/providers/notification_inbox_state.dart';
import 'package:forge/features/notifications/presentation/providers/notification_preferences_controller.dart';
import 'package:forge/features/notifications/presentation/providers/notification_providers.dart';
import 'package:forge/features/onboarding/presentation/onboarding_status_notifier.dart';

import '../../../support/fake_auth_overrides.dart';
import '../../../support/fake_local_notification_service.dart';
import '../../../support/fake_secure_key_value_store.dart';

/// Wraps a real [MockNotificationRepository] but can be toggled to throw
/// on [fetchInbox] — the cheapest way to simulate "the device just went
/// offline / a reconnect fetch failed" without inventing new sync
/// infrastructure: [NotificationInboxController]'s own `_load()` already
/// has a real catch path for exactly this (`state =
/// NotificationInboxError(...)`), so this fake only needs to trigger it.
class _FlakyNotificationRepository implements NotificationRepository {
  _FlakyNotificationRepository(this._inner);

  final MockNotificationRepository _inner;
  bool offline = false;

  @override
  Future<List<ForgeNotification>> fetchInbox() {
    if (offline) throw Exception('simulated offline: no network');
    return _inner.fetchInbox();
  }

  @override
  Future<void> markRead(String notificationId) =>
      _inner.markRead(notificationId);

  @override
  Future<void> markAllRead() => _inner.markAllRead();

  @override
  Future<NotificationPreferences> getPreferences() => _inner.getPreferences();

  @override
  Future<void> updatePreferences(NotificationPreferences preferences) =>
      _inner.updatePreferences(preferences);
}

ForgeNotification _serverNotification(
  String id,
  DateTime createdAt, {
  DateTime? readAt,
}) {
  return ForgeNotification(
    id: id,
    type: ForgeNotificationType.levelUp,
    dedupKey: 'level_up:$id',
    createdAt: createdAt,
    readAt: readAt,
    metadata: const {},
  );
}

List<Override> _baseOverrides(
  NotificationRepository repository, {
  FakeLocalNotificationService? localNotificationService,
  AuthStateNotifier Function()? authNotifierFactory,
}) => [
  authStateNotifierProvider.overrideWith(
    authNotifierFactory ?? FakeAuthenticatedNotifier.new,
  ),
  onboardingStatusProvider.overrideWith(FakeCompletedOnboardingNotifier.new),
  secureKeyValueStoreProvider.overrideWithValue(FakeSecureKeyValueStore()),
  notificationRepositoryProvider.overrideWithValue(repository),
  localNotificationServiceProvider.overrideWithValue(
    localNotificationService ?? FakeLocalNotificationService(),
  ),
];

Future<String> _readyMissionInstanceId(ProviderContainer container) async {
  await container
      .read(resolvedMissionInstanceControllerProvider.notifier)
      .ready;
  return container.read(resolvedMissionInstanceProvider)!.instance.instanceId;
}

void main() {
  test('an unauthenticated session never surfaces a previous session\'s '
      'notifications — stays Loading rather than leaking state', () async {
    final container = ProviderContainer(
      overrides: [
        authStateNotifierProvider.overrideWith(FakeUnauthenticatedNotifier.new),
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
        notificationRepositoryProvider.overrideWithValue(
          MockNotificationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(notificationInboxControllerProvider),
      isA<NotificationInboxLoading>(),
    );
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
    await container
        .read(resolvedMissionInstanceControllerProvider.notifier)
        .ready;
    await container.read(notificationInboxControllerProvider.notifier).ready;
    final state =
        container.read(notificationInboxControllerProvider)
            as NotificationInboxReady;

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
    var state =
        container.read(notificationInboxControllerProvider)
            as NotificationInboxReady;
    final serverNotification = state.notifications.firstWhere(
      (n) => n.id == 'lvl-1',
    );
    expect(serverNotification.isRead, isFalse);

    await container
        .read(notificationInboxControllerProvider.notifier)
        .markRead(serverNotification);

    state =
        container.read(notificationInboxControllerProvider)
            as NotificationInboxReady;
    expect(
      state.notifications.firstWhere((n) => n.id == 'lvl-1').isRead,
      isTrue,
    );

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
    await container
        .read(notificationInboxControllerProvider.notifier)
        .markAllRead();

    final state =
        container.read(notificationInboxControllerProvider)
            as NotificationInboxReady;
    expect(state.notifications.every((n) => n.isRead), isTrue);

    final persisted = await repository.fetchInbox();
    expect(persisted.every((n) => n.isRead), isTrue);
  });

  test('unreadCount reflects only unread notifications, server and local '
      'combined', () async {
    final repository = MockNotificationRepository(
      seed: [
        _serverNotification('lvl-1', DateTime(2020, 1, 1)),
        _serverNotification(
          'lvl-2',
          DateTime(2020, 1, 2),
          readAt: DateTime(2020, 1, 3),
        ),
      ],
    );
    final container = ProviderContainer(overrides: _baseOverrides(repository));
    addTearDown(container.dispose);

    await container
        .read(resolvedMissionInstanceControllerProvider.notifier)
        .ready;
    await container.read(notificationInboxControllerProvider.notifier).ready;
    final state =
        container.read(notificationInboxControllerProvider)
            as NotificationInboxReady;

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
    await container
        .read(missionLifecycleControllerProvider(instanceId).notifier)
        .accept();

    await container.read(notificationInboxControllerProvider.notifier).ready;
    final state =
        container.read(notificationInboxControllerProvider)
            as NotificationInboxReady;

    expect(
      state.notifications.any(
        (n) => n.type == ForgeNotificationType.dailyMission,
      ),
      isFalse,
    );
  });

  test('a disabled category is filtered out of the inbox entirely — a '
      'server-authoritative row still exists, but must not be shown to a '
      'user who opted out of that category', () async {
    final repository = MockNotificationRepository(
      seed: [_serverNotification('lvl-1', DateTime(2020, 1, 1))],
    );
    await repository.updatePreferences(
      const NotificationPreferences(progressionEnabled: false),
    );
    final container = ProviderContainer(overrides: _baseOverrides(repository));
    addTearDown(container.dispose);

    await container.read(notificationInboxControllerProvider.notifier).ready;
    final state =
        container.read(notificationInboxControllerProvider)
            as NotificationInboxReady;

    expect(state.notifications.any((n) => n.id == 'lvl-1'), isFalse);
  });

  test('the master toggle hides every server-authoritative notification, '
      'not just one category', () async {
    final repository = MockNotificationRepository(
      seed: [_serverNotification('lvl-1', DateTime(2020, 1, 1))],
    );
    await repository.updatePreferences(
      const NotificationPreferences(masterEnabled: false),
    );
    final container = ProviderContainer(overrides: _baseOverrides(repository));
    addTearDown(container.dispose);

    await container.read(notificationInboxControllerProvider.notifier).ready;
    final state =
        container.read(notificationInboxControllerProvider)
            as NotificationInboxReady;

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
    var state =
        container.read(notificationInboxControllerProvider)
            as NotificationInboxReady;
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
      if (current is NotificationInboxReady &&
          !current.notifications.any((n) => n.id == 'lvl-1')) {
        refiltered = current;
        break;
      }
    }

    expect(
      refiltered,
      isNotNull,
      reason: 'inbox was never re-filtered after the preference change',
    );
  });

  group('offline / reconnect', () {
    test('a fetch failure (device offline) surfaces a retryable error '
        'state, never a crash or a silently empty inbox', () async {
      final repository = _FlakyNotificationRepository(
        MockNotificationRepository(
          seed: [_serverNotification('lvl-1', DateTime(2020, 1, 1))],
        ),
      )..offline = true;
      final container = ProviderContainer(
        overrides: _baseOverrides(repository),
      );
      addTearDown(container.dispose);

      await container.read(notificationInboxControllerProvider.notifier).ready;
      expect(
        container.read(notificationInboxControllerProvider),
        isA<NotificationInboxError>(),
      );
    });

    test(
      'reconnecting (retrying after a failed fetch) recovers the real '
      'cached-on-the-server notifications once the network is back',
      () async {
        // Two containers sharing the same underlying repository/store —
        // the cleanest available way to simulate "the app reconnected"
        // (a fresh session re-fetching against a backend whose state
        // persisted the whole time) without fighting a bare
        // ProviderContainer's own `invalidate` rebuild timing, which has
        // no dedicated `ready` signal to await for a second load.
        final inner = MockNotificationRepository(
          seed: [_serverNotification('lvl-1', DateTime(2020, 1, 1))],
        );
        final repository = _FlakyNotificationRepository(inner)..offline = true;

        final offlineContainer = ProviderContainer(
          overrides: _baseOverrides(repository),
        );
        await offlineContainer
            .read(notificationInboxControllerProvider.notifier)
            .ready;
        expect(
          offlineContainer.read(notificationInboxControllerProvider),
          isA<NotificationInboxError>(),
        );
        offlineContainer.dispose();

        repository.offline = false;
        final onlineContainer = ProviderContainer(
          overrides: _baseOverrides(repository),
        );
        addTearDown(onlineContainer.dispose);
        await onlineContainer
            .read(notificationInboxControllerProvider.notifier)
            .ready;

        final state =
            onlineContainer.read(notificationInboxControllerProvider)
                as NotificationInboxReady;
        expect(state.notifications.any((n) => n.id == 'lvl-1'), isTrue);
      },
    );

    test('reconnecting never duplicates a notification that was already '
        'shown — a repeated load is idempotent, not additive', () async {
      final inner = MockNotificationRepository(
        seed: [_serverNotification('lvl-1', DateTime(2020, 1, 1))],
      );
      final repository = _FlakyNotificationRepository(inner);

      final first = ProviderContainer(overrides: _baseOverrides(repository));
      await first.read(notificationInboxControllerProvider.notifier).ready;
      first.dispose();

      final second = ProviderContainer(overrides: _baseOverrides(repository));
      addTearDown(second.dispose);
      await second.read(notificationInboxControllerProvider.notifier).ready;

      final state =
          second.read(notificationInboxControllerProvider)
              as NotificationInboxReady;
      expect(state.notifications.where((n) => n.id == 'lvl-1').length, 1);
    });

    test('a read-state change survives a reconnect — the mark-read call '
        'was already persisted server-side, so a fresh fetch after '
        'coming back online reflects it correctly rather than reverting '
        'to unread', () async {
      final inner = MockNotificationRepository(
        seed: [_serverNotification('lvl-1', DateTime(2020, 1, 1))],
      );
      final repository = _FlakyNotificationRepository(inner);

      final firstSession = ProviderContainer(
        overrides: _baseOverrides(repository),
      );
      await firstSession
          .read(notificationInboxControllerProvider.notifier)
          .ready;
      final initial =
          firstSession.read(notificationInboxControllerProvider)
              as NotificationInboxReady;
      await firstSession
          .read(notificationInboxControllerProvider.notifier)
          .markRead(initial.notifications.firstWhere((n) => n.id == 'lvl-1'));
      firstSession.dispose();

      // Simulate a full reconnect cycle: a fresh session re-fetches
      // against the same backend, which already persisted the read.
      final reconnectedSession = ProviderContainer(
        overrides: _baseOverrides(repository),
      );
      addTearDown(reconnectedSession.dispose);
      await reconnectedSession
          .read(notificationInboxControllerProvider.notifier)
          .ready;

      final state =
          reconnectedSession.read(notificationInboxControllerProvider)
              as NotificationInboxReady;
      expect(
        state.notifications.firstWhere((n) => n.id == 'lvl-1').isRead,
        isTrue,
      );
    });
  });

  group('Roadmap Item 17: OS-level local notifications', () {
    test('a due daily-mission reminder is mirrored to the OS via '
        'showNow, using the exact same eligibility LocalReminderEngine '
        'already computed for the in-app inbox', () async {
      final localNotificationService = FakeLocalNotificationService();
      final container = ProviderContainer(
        overrides: _baseOverrides(
          MockNotificationRepository(),
          localNotificationService: localNotificationService,
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(resolvedMissionInstanceControllerProvider.notifier)
          .ready;
      await container.read(notificationInboxControllerProvider.notifier).ready;

      expect(localNotificationService.shown, isNotEmpty);
    });

    test('client-owned local reminders still get mirrored to the OS even '
        'when the server fetch fails — offline behavior must not depend '
        'on backend connectivity (spec section 15)', () async {
      final localNotificationService = FakeLocalNotificationService();
      final repository = _FlakyNotificationRepository(
        MockNotificationRepository(),
      )..offline = true;
      final container = ProviderContainer(
        overrides: _baseOverrides(
          repository,
          localNotificationService: localNotificationService,
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(resolvedMissionInstanceControllerProvider.notifier)
          .ready;
      await container.read(notificationInboxControllerProvider.notifier).ready;

      // The inbox state still surfaces the retryable error (unchanged
      // existing contract)...
      expect(
        container.read(notificationInboxControllerProvider),
        isA<NotificationInboxError>(),
      );
      // ...but the OS-level reminder still fired regardless.
      expect(localNotificationService.shown, isNotEmpty);
    });

    test('signing out cancels every locally-scheduled OS reminder — '
        'account-switch isolation (spec section 14)', () async {
      final localNotificationService = FakeLocalNotificationService();
      final authNotifier = FakeAuthenticatedNotifier();
      final container = ProviderContainer(
        overrides: _baseOverrides(
          MockNotificationRepository(),
          localNotificationService: localNotificationService,
          authNotifierFactory: () => authNotifier,
        ),
      );
      addTearDown(container.dispose);

      await container.read(notificationInboxControllerProvider.notifier).ready;
      expect(localNotificationService.cancelAllCalled, isFalse);
      expect(
        container.read(authStateNotifierProvider).status,
        AuthStatus.authenticated,
      );

      await authNotifier.signOut();
      expect(
        container.read(authStateNotifierProvider).status,
        AuthStatus.unauthenticated,
        reason: 'signOut() itself must have flipped the auth status',
      );
      // The rebuild this triggers, and the cancel call inside it, are
      // both async with no dedicated signal of their own to await —
      // poll a bounded number of microtask turns rather than assume a
      // fixed delay is enough (same technique already used above for
      // the preference-change reactive-rebuild test).
      var cancelled = false;
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(Duration.zero);
        // Riverpod only recomputes a provider nothing is actively
        // watching once something reads it again — re-reading here
        // forces NotificationInboxController.build() to actually run
        // for the now-unauthenticated status if it hasn't already.
        container.read(notificationInboxControllerProvider);
        if (localNotificationService.cancelAllCalled) {
          cancelled = true;
          break;
        }
      }

      expect(
        cancelled,
        isTrue,
        reason: 'cancelAll was never called after sign-out',
      );
    });

    test('a mission follow-up is genuinely scheduled in advance (not '
        'just mirrored via showNow) once the mission is accepted', () async {
      final localNotificationService = FakeLocalNotificationService();
      final repository = MockNotificationRepository();
      final container = ProviderContainer(
        overrides: _baseOverrides(
          repository,
          localNotificationService: localNotificationService,
        ),
      );
      addTearDown(container.dispose);

      final instanceId = await _readyMissionInstanceId(container);
      await container
          .read(missionLifecycleControllerProvider(instanceId).notifier)
          .accept();

      await container.read(notificationInboxControllerProvider.notifier).ready;

      final id = LocalNotificationScheduler.stableId(
        'mission_followup:$instanceId',
      );
      expect(localNotificationService.scheduled.containsKey(id), isTrue);
    });
  });
}
