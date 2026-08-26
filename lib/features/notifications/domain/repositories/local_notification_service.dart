/// OS-level notification permission state (Roadmap Item 17 section 6) —
/// deliberately a closed enum, not a raw bool, because "not yet asked"
/// and "asked and refused" require different UI treatment (no repeated
/// nagging) and [unsupported] (e.g. this build running on Web) is a
/// distinct case from either — never conflated with [denied].
enum LocalNotificationPermissionStatus {
  /// This platform has no local-notification delivery path in this app
  /// (Web, in this pass — see [LocalNotificationService]'s own doc
  /// comment for why). Requesting permission is never attempted.
  unsupported,

  /// Supported here, but the user has never been asked.
  notDetermined,

  /// The user was asked and said no (or the OS setting is off) —
  /// [LocalNotificationService.requestPermission] must not be called
  /// again automatically; only an explicit user action may retry.
  denied,

  granted,
}

/// The only seam between Forge's notification domain and an actual
/// device notification tray (Roadmap Item 17). Nothing above this
/// interface — [LocalNotificationScheduler], Settings UI, or anywhere
/// else — ever imports a notification plugin directly; everything below
/// it (a real plugin-backed implementation, or a platform that simply
/// doesn't support this) is swappable and independently fakeable.
///
/// Deliberately narrow: this has no opinion about *what* Forge shows or
/// *when* — [ForgeNotificationType], [NotificationPreferences], and
/// [LocalReminderEngine] (all pre-existing, Roadmap Item 15) remain the
/// only source of notification meaning. This is a delivery mechanism,
/// nothing more.
abstract class LocalNotificationService {
  /// Must be called once before any other method does anything useful.
  /// [onTap] fires with whatever string was passed as `payload` to
  /// [showNow]/[schedule] when the user taps a *currently-alive-app*
  /// notification (foreground or backgrounded-but-not-terminated) — a
  /// cold-start tap is instead surfaced via [consumeLaunchPayload].
  /// Implementations must never throw: a platform/plugin failure here
  /// is a capability question, reflected in [permissionStatus] as
  /// [LocalNotificationPermissionStatus.unsupported], not an exception
  /// call sites must guard against individually.
  Future<void> initialize({required void Function(String payload) onTap});

  Future<LocalNotificationPermissionStatus> permissionStatus();

  /// Only ever called from an explicit user action (Settings) — never
  /// automatically, and never repeated once the result is [denied]
  /// (spec section 6: "no repeated nagging").
  Future<LocalNotificationPermissionStatus> requestPermission();

  /// Shows a notification immediately.
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
  });

  /// Schedules a notification for a future local instant. Calling this
  /// again with the same [id] replaces whatever was previously
  /// scheduled under it (Roadmap Item 17 section 10 — stable ids are
  /// the whole dedup/reschedule contract, never a random id).
  Future<void> schedule({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  });

  Future<void> cancel(int id);

  Future<void> cancelAll();

  /// The payload of whichever notification launched the app from fully
  /// terminated (cold start), if any — `null` otherwise. One-shot: a
  /// second call in the same app session returns `null` even if the
  /// same launch details are still true, so a caller can safely call
  /// this once at startup without re-navigating on every rebuild.
  Future<String?> consumeLaunchPayload();
}
