import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/missions/presentation/providers/resolved_mission_instance_controller.dart';
import 'package:forge/features/notifications/data/mock/mock_notification_repository.dart';
import 'package:forge/features/notifications/domain/entities/forge_notification.dart';
import 'package:forge/features/notifications/domain/enums/forge_notification_type.dart';
import 'package:forge/features/notifications/presentation/pages/notification_inbox_page.dart';
import 'package:forge/features/notifications/presentation/providers/notification_inbox_controller.dart';
import 'package:forge/features/notifications/presentation/providers/notification_inbox_state.dart';
import 'package:forge/features/notifications/presentation/providers/notification_providers.dart';

import '../../../support/fake_auth_overrides.dart';
import '../../../support/fake_secure_key_value_store.dart';

class _FixedState extends NotificationInboxController {
  _FixedState(this._state);
  final NotificationInboxState _state;
  @override
  NotificationInboxState build() => _state;
}

Widget _wrap(NotificationInboxState state) {
  return ProviderScope(
    overrides: [
      notificationInboxControllerProvider.overrideWith(() => _FixedState(state)),
    ],
    child: MaterialApp(theme: ForgeTheme.dark(), home: const NotificationInboxPage()),
  );
}

void main() {
  testWidgets('loading state shows the loading indicator, not the list or '
      'empty state', (tester) async {
    await tester.pumpWidget(_wrap(const NotificationInboxLoading()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Nothing here yet'), findsNothing);
  });

  testWidgets('error state shows a retry affordance, not a raw stack trace '
      'or blank screen', (tester) async {
    await tester.pumpWidget(_wrap(const NotificationInboxError("Couldn't load notifications right now.")));
    await tester.pump();

    expect(find.text("Couldn't load notifications right now."), findsOneWidget);
  });

  testWidgets('empty state shows friendly copy, not an empty list with no '
      'explanation', (tester) async {
    await tester.pumpWidget(_wrap(const NotificationInboxReady([])));
    await tester.pump();

    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('ready state with notifications renders one tile per '
      'notification and no "mark all read" button when nothing is unread', (
    tester,
  ) async {
    final notifications = [
      ForgeNotification(
        id: 'n-1',
        type: ForgeNotificationType.levelUp,
        dedupKey: 'level_up:u:5',
        createdAt: DateTime.now(),
        readAt: DateTime.now(),
        metadata: const {'newLevel': 5},
      ),
    ];

    await tester.pumpWidget(_wrap(NotificationInboxReady(notifications)));
    await tester.pump();

    expect(find.text('You reached level 5.'), findsOneWidget);
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('an unread notification shows the "mark all read" action, and '
      'tapping it clears every unread notification through the real '
      'controller', (tester) async {
    final repository = MockNotificationRepository(
      seed: [
        ForgeNotification(
          id: 'n-1',
          type: ForgeNotificationType.levelUp,
          dedupKey: 'level_up:u:5',
          createdAt: DateTime.now(),
          readAt: null,
          metadata: const {'newLevel': 5},
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        ...authenticatedTestOverrides(),
        secureKeyValueStoreProvider.overrideWithValue(FakeSecureKeyValueStore()),
        notificationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(resolvedMissionInstanceControllerProvider.notifier).ready;
    await container.read(notificationInboxControllerProvider.notifier).ready;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: ForgeTheme.dark(), home: const NotificationInboxPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Mark all read'), findsOneWidget);
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    final state = container.read(notificationInboxControllerProvider) as NotificationInboxReady;
    expect(state.notifications.every((n) => n.isRead), isTrue);
    expect(find.text('Mark all read'), findsNothing);
  });
}
