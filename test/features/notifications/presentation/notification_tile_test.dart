import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/notifications/domain/entities/forge_notification.dart';
import 'package:forge/features/notifications/domain/enums/forge_notification_type.dart';
import 'package:forge/features/notifications/presentation/widgets/notification_tile.dart';

Widget _wrap(ForgeNotification notification, VoidCallback onTap) {
  return MaterialApp(
    theme: ForgeTheme.dark(),
    home: Scaffold(
      body: NotificationTile(notification: notification, onTap: onTap),
    ),
  );
}

void main() {
  testWidgets('renders the deterministic title and body for its type', (
    tester,
  ) async {
    final notification = ForgeNotification(
      id: 'n-1',
      type: ForgeNotificationType.achievementUnlock,
      dedupKey: 'achievement:u:a',
      createdAt: DateTime.now(),
      readAt: null,
      metadata: const {'title': 'First Steps'},
    );

    await tester.pumpWidget(_wrap(notification, () {}));

    expect(find.text('Achievement unlocked'), findsOneWidget);
    expect(find.text('First Steps'), findsOneWidget);
  });

  testWidgets('invokes onTap when tapped', (tester) async {
    var tapped = false;
    final notification = ForgeNotification(
      id: 'n-1',
      type: ForgeNotificationType.levelUp,
      dedupKey: 'level_up:u:5',
      createdAt: DateTime.now(),
      readAt: null,
      metadata: const {'newLevel': 5},
    );

    await tester.pumpWidget(_wrap(notification, () => tapped = true));
    await tester.tap(find.byType(NotificationTile));

    expect(tapped, isTrue);
  });

  testWidgets('unread notifications expose an "Unread." semantics prefix; '
      'read ones do not', (tester) async {
    final unread = ForgeNotification(
      id: 'n-1',
      type: ForgeNotificationType.levelUp,
      dedupKey: 'level_up:u:5',
      createdAt: DateTime.now(),
      readAt: null,
      metadata: const {'newLevel': 5},
    );
    final read = unread.copyWith(readAt: DateTime.now());

    await tester.pumpWidget(_wrap(unread, () {}));
    expect(
      tester.getSemantics(find.byType(NotificationTile)).label,
      startsWith('Unread.'),
    );

    await tester.pumpWidget(_wrap(read, () {}));
    expect(
      tester.getSemantics(find.byType(NotificationTile)).label,
      isNot(startsWith('Unread.')),
    );
  });
}
