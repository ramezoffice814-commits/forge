import 'package:flutter/foundation.dart';

import '../../domain/entities/forge_notification.dart';

@immutable
sealed class NotificationInboxState {
  const NotificationInboxState();
}

class NotificationInboxLoading extends NotificationInboxState {
  const NotificationInboxLoading();
}

class NotificationInboxError extends NotificationInboxState {
  const NotificationInboxError(this.message);
  final String message;
}

@immutable
class NotificationInboxReady extends NotificationInboxState {
  const NotificationInboxReady(this.notifications);

  final List<ForgeNotification> notifications;

  int get unreadCount => notifications.where((n) => !n.isRead).length;
}
