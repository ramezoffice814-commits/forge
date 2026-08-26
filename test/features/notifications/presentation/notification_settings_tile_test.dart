import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/notifications/data/mock/mock_notification_repository.dart';
import 'package:forge/features/notifications/domain/entities/notification_preferences.dart';
import 'package:forge/features/notifications/domain/entities/quiet_hours.dart';
import 'package:forge/features/notifications/presentation/providers/notification_preferences_controller.dart';
import 'package:forge/features/notifications/presentation/providers/notification_providers.dart';
import 'package:forge/features/notifications/presentation/widgets/notification_settings_tile.dart';

import '../../../support/fake_auth_overrides.dart';
import '../../../support/fake_secure_key_value_store.dart';

Future<ProviderContainer> _pumpTile(
  WidgetTester tester, {
  MockNotificationRepository? repository,
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
      child: MaterialApp(
        theme: ForgeTheme.dark(),
        home: const Scaffold(
          body: SingleChildScrollView(child: NotificationSettingsTile()),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('shows every category toggle when the master switch is on', (
    tester,
  ) async {
    await _pumpTile(tester);

    expect(find.text('All notifications'), findsOneWidget);
    expect(find.text('Daily mission reminder'), findsOneWidget);
    expect(find.text('Daily transmission reminder'), findsOneWidget);
    expect(find.text('Mission follow-up'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('Level-ups'), findsOneWidget);
    expect(find.text('Weekly recap'), findsOneWidget);
    expect(find.text('Competition results'), findsOneWidget);
    expect(find.text('Occasional check-ins'), findsOneWidget);
    expect(find.text('Quiet hours'), findsOneWidget);
  });

  testWidgets('turning the master switch off hides every category toggle and '
      'quiet hours, without deleting the underlying preference values', (
    tester,
  ) async {
    final container = await _pumpTile(tester);

    await tester.tap(find.text('All notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Daily mission reminder'), findsNothing);
    expect(find.text('Quiet hours'), findsNothing);
    expect(
      container.read(notificationPreferencesControllerProvider).masterEnabled,
      isFalse,
    );
  });

  testWidgets('toggling a category persists through the real controller to '
      'the repository', (tester) async {
    final repository = MockNotificationRepository();
    final container = await _pumpTile(tester, repository: repository);

    await tester.tap(find.text('Achievements'));
    await tester.pumpAndSettle();

    expect(
      container
          .read(notificationPreferencesControllerProvider)
          .achievementEnabled,
      isFalse,
    );
    final persisted = await repository.getPreferences();
    expect(persisted.achievementEnabled, isFalse);
  });

  testWidgets('re-engagement defaults off and can be opted into', (
    tester,
  ) async {
    final container = await _pumpTile(tester);
    expect(
      container
          .read(notificationPreferencesControllerProvider)
          .reEngagementEnabled,
      isFalse,
    );

    await tester.tap(find.text('Occasional check-ins'));
    await tester.pumpAndSettle();

    expect(
      container
          .read(notificationPreferencesControllerProvider)
          .reEngagementEnabled,
      isTrue,
    );
  });

  testWidgets('quiet-hours time pickers only appear once quiet hours is '
      'enabled', (tester) async {
    await _pumpTile(tester);

    expect(find.textContaining('Start:'), findsNothing);
    expect(find.textContaining('End:'), findsNothing);

    await tester.tap(find.text('Quiet hours'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Start:'), findsOneWidget);
    expect(find.textContaining('End:'), findsOneWidget);
  });

  testWidgets('quiet hours starts from the persisted preference values, not '
      'a hardcoded default', (tester) async {
    final repository = MockNotificationRepository();
    await repository.updatePreferences(
      const NotificationPreferences(
        quietHours: QuietHours(enabled: true, startMinute: 60, endMinute: 300),
      ),
    );
    await _pumpTile(tester, repository: repository);

    expect(find.textContaining('1:00'), findsOneWidget);
    expect(find.textContaining('5:00'), findsOneWidget);
  });
}
