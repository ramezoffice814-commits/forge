import '../../domain/repositories/local_notification_service.dart';

/// Used on Web (Roadmap Item 17 section 3): `flutter_local_notifications`
/// technically ships a Web implementation, but it depends on a service
/// worker for tap-handling consistency — close enough to the "web push
/// infrastructure" this item was explicitly told not to add that
/// treating it as in scope would be a stretch of that instruction, not a
/// good-faith reading of it. Rather than wire a half-supported path,
/// Web deliberately gets an honest no-op: [permissionStatus] always
/// reports [LocalNotificationPermissionStatus.unsupported], nothing is
/// ever scheduled or shown, and the existing in-app inbox (Item 15)
/// remains the only notification surface there — exactly the "graceful
/// no-op/in-app-only" the item's own brief asked for.
class UnsupportedLocalNotificationService implements LocalNotificationService {
  const UnsupportedLocalNotificationService();

  @override
  Future<void> initialize({
    required void Function(String payload) onTap,
  }) async {}

  @override
  Future<LocalNotificationPermissionStatus> permissionStatus() async =>
      LocalNotificationPermissionStatus.unsupported;

  @override
  Future<LocalNotificationPermissionStatus> requestPermission() async =>
      LocalNotificationPermissionStatus.unsupported;

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {}

  @override
  Future<void> schedule({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<String?> consumeLaunchPayload() async => null;
}
