import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_privacy_level.dart';
import 'package:forge/features/ai_coach/presentation/providers/ai_coach_providers.dart';
import 'package:forge/features/notifications/data/mock/mock_notification_repository.dart';
import 'package:forge/features/notifications/domain/entities/forge_notification.dart';
import 'package:forge/features/notifications/domain/entities/notification_preferences.dart';
import 'package:forge/features/notifications/domain/repositories/notification_repository.dart';
import 'package:forge/features/notifications/presentation/providers/notification_preferences_controller.dart';
import 'package:forge/features/notifications/presentation/providers/notification_providers.dart';
import 'package:forge/features/settings/presentation/pages/settings_page.dart';

import '../../../support/fake_auth_overrides.dart';
import '../../../support/fake_secure_key_value_store.dart';

/// A [NotificationRepository] whose `getPreferences` always fails — the
/// cheapest way to prove `NotificationPreferencesController`'s existing
/// "advisory, never load-bearing" fallback (safe defaults on a failed
/// load) still holds once hosted inside [SettingsPage].
class _FailingPreferencesRepository implements NotificationRepository {
  _FailingPreferencesRepository(this._inner);
  final MockNotificationRepository _inner;

  @override
  Future<NotificationPreferences> getPreferences() =>
      Future.error(Exception('simulated preferences load failure'));

  @override
  Future<List<ForgeNotification>> fetchInbox() => _inner.fetchInbox();

  @override
  Future<void> markRead(String notificationId) =>
      _inner.markRead(notificationId);

  @override
  Future<void> markAllRead() => _inner.markAllRead();

  @override
  Future<void> updatePreferences(NotificationPreferences preferences) =>
      _inner.updatePreferences(preferences);
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  NotificationRepository? repository,
}) async {
  final container = ProviderContainer(
    overrides: [
      ...authenticatedTestOverrides(),
      secureKeyValueStoreProvider.overrideWithValue(FakeSecureKeyValueStore()),
      notificationRepositoryProvider.overrideWithValue(
        repository ?? MockNotificationRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(notificationPreferencesControllerProvider.notifier)
      .ready;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: ForgeTheme.dark(), home: const SettingsPage()),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('renders every section: account, AI, notifications, '
      'accessibility, about', (tester) async {
    await _pump(tester);

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('AI Coach'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Accessibility'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('AI privacy control moved into Settings still reads/writes '
      'the exact same aiPrivacyLevelProvider Profile used to host — no '
      'second privacy state, no behavior regression', (tester) async {
    final container = await _pump(tester);
    expect(
      container.read(aiPrivacyLevelProvider),
      AiPrivacyLevel.limitedContext,
    );

    await tester.tap(find.text('Off — no AI coaching'));
    await tester.pumpAndSettle();

    expect(container.read(aiPrivacyLevelProvider), AiPrivacyLevel.disabled);
  });

  testWidgets('notification category toggle moved into Settings still '
      'persists through the real NotificationPreferencesController', (
    tester,
  ) async {
    final repository = MockNotificationRepository();
    await _pump(tester, repository: repository);

    await tester.ensureVisible(find.text('Achievements'));
    await tester.tap(find.text('Achievements'));
    await tester.pumpAndSettle();

    final persisted = await repository.getPreferences();
    expect(persisted.achievementEnabled, isFalse);
  });

  testWidgets('quiet hours toggle is reachable from Settings and reveals '
      'the start/end time controls', (tester) async {
    await _pump(tester);

    expect(find.textContaining('Start:'), findsNothing);
    await tester.ensureVisible(find.text('Quiet hours'));
    await tester.tap(find.text('Quiet hours'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Start:'), findsOneWidget);
    expect(find.textContaining('End:'), findsOneWidget);
  });

  testWidgets('renders safely even when the notification repository fails '
      'to load — falls back to safe defaults rather than crashing the '
      'whole Settings page', (tester) async {
    final repository = _FailingPreferencesRepository(
      MockNotificationRepository(),
    );
    await _pump(tester, repository: repository);

    expect(tester.takeException(), isNull);
    expect(find.text('Notifications'), findsOneWidget);
    // The master toggle still renders in its safe default (on) state.
    expect(find.text('All notifications'), findsOneWidget);
  });

  testWidgets('renders without overflow at a large device text scale '
      '(accessibility large-text support)', (tester) async {
    final container = ProviderContainer(
      overrides: [
        ...authenticatedTestOverrides(),
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
        notificationRepositoryProvider.overrideWithValue(
          MockNotificationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(notificationPreferencesControllerProvider.notifier)
        .ready;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ForgeTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('accessibility status row exposes a semantic label describing '
      'the current reduced-motion state', (tester) async {
    await _pump(tester);

    final semanticsHandle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(
        RegExp('Reduced motion is (on|off), following your device setting'),
      ),
      findsOneWidget,
    );
    semanticsHandle.dispose();
  });
}
