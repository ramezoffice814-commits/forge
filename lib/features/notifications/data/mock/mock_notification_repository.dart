import '../../domain/entities/forge_notification.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_repository.dart';

/// Deterministic, in-memory — the only repository mock backend mode
/// ever uses. Seeded with nothing by default; tests/widget scenarios
/// inject whatever server-authoritative notifications they need via
/// [seed].
class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository({List<ForgeNotification> seed = const []})
    : _notifications = List.of(seed);

  final List<ForgeNotification> _notifications;
  NotificationPreferences _preferences = const NotificationPreferences();

  @override
  Future<List<ForgeNotification>> fetchInbox() async {
    final sorted = List<ForgeNotification>.of(_notifications)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<void> markRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;
    _notifications[index] = _notifications[index].copyWith(
      readAt: DateTime.now(),
    );
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      if (_notifications[i].readAt == null) {
        _notifications[i] = _notifications[i].copyWith(readAt: DateTime.now());
      }
    }
  }

  @override
  Future<NotificationPreferences> getPreferences() async => _preferences;

  @override
  Future<void> updatePreferences(NotificationPreferences preferences) async {
    _preferences = preferences;
  }
}
