import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/notifications/domain/repositories/local_notification_service.dart';
import 'package:forge/features/notifications/presentation/providers/notification_providers.dart';
import 'package:forge/features/notifications/presentation/widgets/os_notification_settings_tile.dart';

import '../../../support/fake_local_notification_service.dart';

Future<FakeLocalNotificationService> _pump(
  WidgetTester tester, {
  LocalNotificationPermissionStatus initialStatus =
      LocalNotificationPermissionStatus.notDetermined,
}) async {
  final service = FakeLocalNotificationService()..status = initialStatus;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localNotificationServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: ForgeTheme.dark(),
        home: const Scaffold(body: OsNotificationSettingsTile()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  testWidgets('unsupported platform shows an honest explanation, no button', (
    tester,
  ) async {
    await _pump(
      tester,
      initialStatus: LocalNotificationPermissionStatus.unsupported,
    );

    expect(
      find.textContaining('Not available on this platform'),
      findsOneWidget,
    );
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets(
    'not-yet-determined shows a "Turn on" action, and tapping it requests '
    'permission',
    (tester) async {
      final service = await _pump(
        tester,
        initialStatus: LocalNotificationPermissionStatus.notDetermined,
      );

      expect(find.text('Turn on device notifications'), findsOneWidget);

      await tester.tap(find.text('Turn on device notifications'));
      await tester.pumpAndSettle();

      expect(service.status, LocalNotificationPermissionStatus.granted);
      expect(find.textContaining('On —'), findsOneWidget);
    },
  );

  testWidgets(
    'denied shows a no-nagging explanation — no button to tap again',
    (tester) async {
      await _pump(
        tester,
        initialStatus: LocalNotificationPermissionStatus.denied,
      );

      expect(find.textContaining('turned off'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    },
  );

  testWidgets('granted shows an on/enabled confirmation', (tester) async {
    await _pump(
      tester,
      initialStatus: LocalNotificationPermissionStatus.granted,
    );

    expect(find.textContaining('On —'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
  });
}
