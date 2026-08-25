import '../entities/forge_notification.dart';
import '../entities/notification_preferences.dart';

/// Server-authoritative notifications only — [fetchInbox]/[markRead]/
/// [markAllRead] never touch the three client-owned reminder types (see
/// `ForgeNotificationType.isServerAuthoritative`); those are merged in
/// at the presentation layer by `NotificationInboxController` from
/// `LocalReminderEngine` instead, since they never exist server-side to
/// fetch in the first place.
abstract class NotificationRepository {
  Future<List<ForgeNotification>> fetchInbox();
  Future<void> markRead(String notificationId);
  Future<void> markAllRead();
  Future<NotificationPreferences> getPreferences();
  Future<void> updatePreferences(NotificationPreferences preferences);
}
