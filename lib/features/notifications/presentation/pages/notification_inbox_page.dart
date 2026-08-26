import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../../../shared/widgets/forge_empty_state.dart';
import '../../../../shared/widgets/forge_loading_state.dart';
import '../../../../shared/widgets/forge_retry_state.dart';
import '../../domain/entities/forge_notification.dart';
import '../../domain/enums/notification_deep_link.dart';
import 'notification_deep_link_router.dart';
import '../providers/notification_inbox_controller.dart';
import '../providers/notification_inbox_state.dart';
import '../widgets/notification_tile.dart';

/// Forge's notification center (Roadmap Item 15 section 11) — reached
/// from the Dashboard bell icon. Unread/read distinction, mark-read,
/// mark-all-read, empty/loading/error states, and safe deep-link
/// navigation on tap.
class NotificationInboxPage extends ConsumerWidget {
  const NotificationInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final state = ref.watch(notificationInboxControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state is NotificationInboxReady && state.unreadCount > 0)
            TextButton(
              onPressed: () => ref
                  .read(notificationInboxControllerProvider.notifier)
                  .markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: switch (state) {
        NotificationInboxLoading() => const ForgeLoadingState(
          message: 'Loading notifications…',
        ),
        NotificationInboxError(:final message) => ForgeRetryState(
          title: message,
          onRetry: () => ref.invalidate(notificationInboxControllerProvider),
        ),
        NotificationInboxReady(:final notifications)
            when notifications.isEmpty =>
          const ForgeEmptyState(
            title: 'Nothing here yet',
            message:
                'Achievements, level-ups, and weekly results will show up here.',
          ),
        NotificationInboxReady(:final notifications) => ListView.separated(
          padding: EdgeInsets.all(tokens.spacing.space3),
          itemCount: notifications.length,
          separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.space1),
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return NotificationTile(
              notification: notification,
              onTap: () => _handleTap(context, ref, notification),
            );
          },
        ),
      },
    );
  }

  void _handleTap(
    BuildContext context,
    WidgetRef ref,
    ForgeNotification notification,
  ) {
    ref
        .read(notificationInboxControllerProvider.notifier)
        .markRead(notification);
    final destination = NotificationDeepLink.forType(notification.type);
    // Fails safe: an unrecognized type (shouldn't be reachable —
    // NotificationDeepLink.forType is total over the enum — but kept
    // explicit rather than assuming) simply does not navigate.
    if (destination == null) return;
    navigateToDeepLink(context, ref, destination);
  }
}
