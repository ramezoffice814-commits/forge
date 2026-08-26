import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/repositories/local_notification_service.dart';
import '../providers/notification_providers.dart';

/// Device-level notification capability/permission status (Roadmap Item
/// 17 section 17) — deliberately separate from [NotificationSettingsTile]
/// above it in [SettingsPage]: that tile controls *what* Forge is
/// allowed to notify about; this one only reports whether the OS itself
/// will actually let a notification reach the device tray. Nothing here
/// duplicates a category/quiet-hours toggle.
class OsNotificationSettingsTile extends ConsumerWidget {
  const OsNotificationSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final statusAsync = ref.watch(osNotificationPermissionControllerProvider);

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device notifications',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: tokens.spacing.space1),
          statusAsync.when(
            data: (status) => _StatusBody(status: status),
            loading: () => _MutedText(
              tokens: tokens,
              text: 'Checking device notification support…',
            ),
            error: (_, _) => _MutedText(
              tokens: tokens,
              text: "Couldn't determine device notification support.",
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBody extends ConsumerWidget {
  const _StatusBody({required this.status});

  final LocalNotificationPermissionStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return switch (status) {
      LocalNotificationPermissionStatus.unsupported => _MutedText(
        tokens: tokens,
        text:
            'Not available on this platform — the in-app notification '
            'inbox still shows everything.',
      ),
      LocalNotificationPermissionStatus.notDetermined => Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MutedText(
              tokens: tokens,
              text:
                  'Get Daily Mission, Daily Transmission, and Mission '
                  'Follow-up reminders outside the app.',
            ),
            SizedBox(height: tokens.spacing.space1),
            OutlinedButton(
              onPressed: () => unawaited(
                ref
                    .read(osNotificationPermissionControllerProvider.notifier)
                    .requestPermission(),
              ),
              child: const Text('Turn on device notifications'),
            ),
          ],
        ),
      ),
      LocalNotificationPermissionStatus.denied => _MutedText(
        tokens: tokens,
        text:
            'Device notifications are turned off. Enable them in your '
            "system settings to get reminders outside the app — Forge won't "
            'ask again automatically.',
      ),
      LocalNotificationPermissionStatus.granted => Row(
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 18,
            color: tokens.text.withValues(alpha: 0.7),
          ),
          SizedBox(width: tokens.spacing.space2),
          Expanded(
            child: _MutedText(
              tokens: tokens,
              text:
                  'On — reminders enabled above will also reach your '
                  'device notification tray.',
            ),
          ),
        ],
      ),
    };
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText({required this.tokens, required this.text});

  final ForgeTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: tokens.text.withValues(alpha: 0.7),
      ),
    );
  }
}
