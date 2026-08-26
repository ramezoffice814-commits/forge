import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/notifications/data/mock/mock_notification_repository.dart';
import 'package:forge/features/notifications/domain/entities/notification_preferences.dart';
import 'package:forge/features/notifications/domain/entities/quiet_hours.dart';
import 'package:forge/features/notifications/presentation/providers/notification_preferences_controller.dart';
import 'package:forge/features/notifications/presentation/providers/notification_providers.dart';

import '../../../support/fake_auth_overrides.dart';

void main() {
  test('build() returns safe defaults synchronously before the async load '
      'resolves', () async {
    final repository = MockNotificationRepository();
    await repository.updatePreferences(
      const NotificationPreferences(masterEnabled: false),
    );

    final container = ProviderContainer(
      overrides: [
        ...authenticatedTestOverrides(),
        notificationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    // Synchronous read, before awaiting `ready` — must be the safe
    // default, not whatever the repository will eventually return.
    expect(
      container.read(notificationPreferencesControllerProvider).masterEnabled,
      isTrue,
    );
  });

  test(
    'loads the real persisted preferences from the repository once ready',
    () async {
      final repository = MockNotificationRepository();
      await repository.updatePreferences(
        const NotificationPreferences(
          masterEnabled: true,
          achievementEnabled: false,
          quietHours: QuietHours(
            enabled: true,
            startMinute: 1320,
            endMinute: 360,
          ),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          ...authenticatedTestOverrides(),
          notificationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(notificationPreferencesControllerProvider.notifier)
          .ready;
      final loaded = container.read(notificationPreferencesControllerProvider);

      expect(loaded.achievementEnabled, isFalse);
      expect(loaded.quietHours.enabled, isTrue);
      expect(loaded.quietHours.startMinute, 1320);
    },
  );

  test('update() persists the new preferences to the repository, not just '
      'local state', () async {
    final repository = MockNotificationRepository();
    final container = ProviderContainer(
      overrides: [
        ...authenticatedTestOverrides(),
        notificationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(notificationPreferencesControllerProvider.notifier)
        .ready;
    final updated = container
        .read(notificationPreferencesControllerProvider)
        .copyWith(reEngagementEnabled: true, competitionResultEnabled: false);
    await container
        .read(notificationPreferencesControllerProvider.notifier)
        .update(updated);

    expect(
      container
          .read(notificationPreferencesControllerProvider)
          .reEngagementEnabled,
      isTrue,
    );
    final persisted = await repository.getPreferences();
    expect(persisted.reEngagementEnabled, isTrue);
    expect(persisted.competitionResultEnabled, isFalse);
  });

  test('an unauthenticated session never loads or exposes another user\'s '
      'preferences — falls back to safe defaults instead', () async {
    final repository = MockNotificationRepository();
    await repository.updatePreferences(
      const NotificationPreferences(masterEnabled: false),
    );

    final container = ProviderContainer(
      overrides: [
        authStateNotifierProvider.overrideWith(FakeUnauthenticatedNotifier.new),
        notificationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    // Give any stray microtask a chance to run — there should be none,
    // since build() short-circuits before scheduling `_load` at all.
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(notificationPreferencesControllerProvider).masterEnabled,
      isTrue,
    );
  });

  test('AI privacy settings are a separate concern: notification preferences '
      'defaults do not read or depend on any AI privacy provider', () async {
    // No AI-related override supplied at all — if NotificationPreferencesController
    // secretly depended on an AI privacy provider, this container would
    // throw a missing-override/uninitialized-provider error on read.
    final container = ProviderContainer(
      overrides: authenticatedTestOverrides(),
    );
    addTearDown(container.dispose);

    expect(
      () => container.read(notificationPreferencesControllerProvider),
      returnsNormally,
    );
  });
}
