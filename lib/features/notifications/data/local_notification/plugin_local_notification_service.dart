import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/repositories/local_notification_service.dart';

/// The real device-backed implementation (Roadmap Item 17), used on
/// Android and Windows only — see `notification_providers.dart` for the
/// platform gate that keeps this class from ever being constructed on
/// Web (`UnsupportedLocalNotificationService` there instead).
///
/// One notification channel on Android (`forge_reminders`) — every
/// reminder this app sends this pass (Daily Mission, Daily Transmission,
/// Mission Follow-up) is the same kind of thing to a user deciding
/// whether to mute it, so one well-named channel beats three
/// near-identical ones (spec section 19: "do not overcomplicate channel
/// design"). Achievement/level-up/competition notifications remain
/// inbox-only (pull-based, Item 15) — not mirrored to the OS in this
/// pass; see the Item 17 report for why.
///
/// Every plugin call is wrapped so a platform/plugin failure degrades to
/// "unsupported," never an uncaught exception — a real device could
/// plausibly fail to bind the platform channel for reasons outside this
/// app's control, and the whole point of exposing capability status is
/// to let the rest of the app keep working regardless.
class PluginLocalNotificationService implements LocalNotificationService {
  PluginLocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'forge_reminders';
  static const _channelName = 'Daily reminders';
  static const _channelDescription =
      "Reminders about today's mission, transmission, and mission "
      'follow-ups.';

  // A fixed, arbitrary GUID identifying this app's toast activation
  // callback to Windows — never used to identify a user or device, just
  // a per-app constant the OS uses to route taps back to this process.
  static const _windowsGuid = '8f3b6e2a-7f0e-4b3d-9c1a-2e6d4a5f7c9b';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _launchPayloadConsumed = false;
  void Function(String payload)? _onTap;

  bool get _platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows);

  @override
  Future<void> initialize({
    required void Function(String payload) onTap,
  }) async {
    if (_initialized || !_platformSupported) return;
    _onTap = onTap;
    try {
      tz_data.initializeTimeZones();
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const windowsSettings = WindowsInitializationSettings(
        appName: 'Forge',
        appUserModelId: 'com.forge.app.forge',
        guid: _windowsGuid,
      );
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          windows: windowsSettings,
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null) _onTap?.call(payload);
        },
      );
      if (ok != true) return;
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
          ),
        );
      }
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  @override
  Future<LocalNotificationPermissionStatus> permissionStatus() async {
    if (!_initialized) return LocalNotificationPermissionStatus.unsupported;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      // Windows toast notifications have no in-app runtime permission
      // model — enabled unless the user disabled them in OS settings,
      // which this plugin has no query API for either way.
      return LocalNotificationPermissionStatus.granted;
    }
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final enabled = await android?.areNotificationsEnabled();
      if (enabled == null) {
        return LocalNotificationPermissionStatus.notDetermined;
      }
      return enabled
          ? LocalNotificationPermissionStatus.granted
          : LocalNotificationPermissionStatus.denied;
    } catch (_) {
      return LocalNotificationPermissionStatus.unsupported;
    }
  }

  @override
  Future<LocalNotificationPermissionStatus> requestPermission() async {
    if (!_initialized) return LocalNotificationPermissionStatus.unsupported;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return LocalNotificationPermissionStatus.granted;
    }
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      return granted == true
          ? LocalNotificationPermissionStatus.granted
          : LocalNotificationPermissionStatus.denied;
    } catch (_) {
      return LocalNotificationPermissionStatus.unsupported;
    }
  }

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
    ),
  );

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details,
        payload: payload,
      );
    } catch (_) {
      // Best-effort delivery — a failed show() has nothing further to
      // retry against here; the next resync will try again.
    }
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_initialized) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        // TZDateTime.from normalizes by the instant's own UTC value, so
        // wrapping in tz.UTC here doesn't change *when* this actually
        // fires — only how the plugin displays/labels it internally.
        // Avoids depending on `flutter_timezone` just to name the
        // device's IANA zone.
        scheduledDate: tz.TZDateTime.from(scheduledAt.toUtc(), tz.UTC),
        notificationDetails: _details,
        payload: payload,
        // No SCHEDULE_EXACT_ALARM permission required (spec section 18:
        // "do not request invasive permissions unnecessarily") — these
        // are reminders, not time-critical alarms, so a short delivery
        // window is an acceptable trade.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // Best-effort — next resync recomputes and retries.
    }
  }

  @override
  Future<void> cancel(int id) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {
      // Windows without MSIX packaging silently no-ops cancel() by the
      // plugin's own documented design — nothing further to do here.
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // See cancel() above.
    }
  }

  @override
  Future<String?> consumeLaunchPayload() async {
    if (!_initialized || _launchPayloadConsumed) return null;
    _launchPayloadConsumed = true;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return details.notificationResponse?.payload;
    } catch (_) {
      return null;
    }
  }
}
