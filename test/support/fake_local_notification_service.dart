import 'package:forge/features/notifications/domain/repositories/local_notification_service.dart';

class ScheduledEntry {
  ScheduledEntry({
    required this.title,
    required this.body,
    required this.payload,
    this.scheduledAt,
  });

  final String title;
  final String body;
  final String payload;

  /// `null` for something shown via [FakeLocalNotificationService.showNow]
  /// rather than genuinely scheduled — distinguishes the two call paths
  /// for assertions that care which one fired.
  final DateTime? scheduledAt;
}

/// In-memory stand-in for [LocalNotificationService] (Roadmap Item 17) —
/// records every call instead of touching a real plugin, following
/// [FakeSecureKeyValueStore]'s own "implement the interface, no async
/// delay, plain in-memory state" convention. [permissionStatus] is
/// settable so a test can simulate every case
/// ([LocalNotificationPermissionStatus.unsupported]/[notDetermined]/
/// [denied]/[granted]) without touching a platform channel.
class FakeLocalNotificationService implements LocalNotificationService {
  LocalNotificationPermissionStatus status =
      LocalNotificationPermissionStatus.notDetermined;

  final Map<int, ScheduledEntry> shown = {};
  final Map<int, ScheduledEntry> scheduled = {};
  bool initializeCalled = false;
  bool cancelAllCalled = false;
  void Function(String payload)? _onTap;
  String? launchPayload;

  @override
  Future<void> initialize({
    required void Function(String payload) onTap,
  }) async {
    initializeCalled = true;
    _onTap = onTap;
  }

  @override
  Future<LocalNotificationPermissionStatus> permissionStatus() async => status;

  @override
  Future<LocalNotificationPermissionStatus> requestPermission() async {
    if (status == LocalNotificationPermissionStatus.notDetermined) {
      status = LocalNotificationPermissionStatus.granted;
    }
    return status;
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    shown[id] = ScheduledEntry(title: title, body: body, payload: payload);
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {
    scheduled[id] = ScheduledEntry(
      title: title,
      body: body,
      payload: payload,
      scheduledAt: scheduledAt,
    );
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalled = true;
    shown.clear();
    scheduled.clear();
  }

  @override
  Future<String?> consumeLaunchPayload() async {
    final payload = launchPayload;
    launchPayload = null;
    return payload;
  }

  /// Test helper — simulates the user tapping a live (non-cold-start)
  /// notification, exactly as the real plugin's own tap callback would.
  void simulateTap(String payload) => _onTap?.call(payload);
}
