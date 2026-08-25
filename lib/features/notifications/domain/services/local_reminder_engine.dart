import '../entities/forge_notification.dart';
import '../entities/notification_preferences.dart';
import '../enums/forge_notification_type.dart';

/// Decides whether/when the three CLIENT OWNED reminder types (Daily
/// Mission, Daily Transmission, Mission Follow-up) should appear —
/// Roadmap Item 15 sections 4A-4C and 16 ("retention safety": cooldown,
/// dedup, quiet hours, no follow-up for an already-completed mission,
/// no repeated nagging). Every method is pure — no I/O, no clock reads
/// — so every rule here is unit-testable without a fake clock/widget
/// tree. Callers own persisting "last shown" (see
/// `LocalReminderStore`) and re-deriving current mission/lifecycle
/// state from the same authoritative providers the rest of the app
/// already uses (`resolvedMissionInstanceProvider`,
/// `MissionLifecycleController`) — this class never invents or selects
/// a mission itself, only decides whether to mention the one it's told
/// about.
abstract final class LocalReminderEngine {
  /// Minimum gap between two Mission Follow-up reminders for the same
  /// mission instance.
  static const followupCooldown = Duration(hours: 6);

  /// A follow-up is never shown before the mission has been actively
  /// worked on for at least this long — an accept-and-immediately-
  /// remind loop would read as nagging, not help.
  static const followupMinimumAge = Duration(hours: 4);

  static bool _blockedByPreferencesOrQuietHours({
    required NotificationPreferences preferences,
    required bool categoryEnabled,
    required DateTime localNow,
  }) {
    if (!preferences.masterEnabled) return true;
    if (!categoryEnabled) return true;
    if (preferences.quietHours.isQuietAt(localNow)) return true;
    return false;
  }

  static bool _shownToday(DateTime? lastShownAt, DateTime localNow) {
    if (lastShownAt == null) return false;
    return lastShownAt.year == localNow.year &&
        lastShownAt.month == localNow.month &&
        lastShownAt.day == localNow.day;
  }

  /// `null` when nothing should be shown — every caller must treat that
  /// as "do nothing," never a fallback default reminder.
  static ForgeNotification? dailyMissionReminder({
    required NotificationPreferences preferences,
    required DateTime localNow,
    required DateTime? lastShownAt,
    required String missionInstanceId,
    required String missionTitle,
    required bool missionAlreadyAccepted,
  }) {
    if (_blockedByPreferencesOrQuietHours(
      preferences: preferences,
      categoryEnabled: preferences.dailyMissionEnabled,
      localNow: localNow,
    )) {
      return null;
    }
    // Already acted on — the reminder did its job or wasn't needed.
    if (missionAlreadyAccepted) return null;
    if (_shownToday(lastShownAt, localNow)) return null;

    final dedupKey = 'daily_mission:${_dateKey(localNow)}';
    return ForgeNotification(
      id: dedupKey,
      type: ForgeNotificationType.dailyMission,
      dedupKey: dedupKey,
      createdAt: localNow,
      readAt: null,
      metadata: {'missionInstanceId': missionInstanceId, 'missionTitle': missionTitle},
    );
  }

  static ForgeNotification? dailyTransmissionReminder({
    required NotificationPreferences preferences,
    required DateTime localNow,
    required DateTime? lastShownAt,
    required bool transmissionAlreadyAvailableToUser,
    required bool missionAlreadyAccepted,
  }) {
    if (_blockedByPreferencesOrQuietHours(
      preferences: preferences,
      categoryEnabled: preferences.dailyTransmissionEnabled,
      localNow: localNow,
    )) {
      return null;
    }
    if (!transmissionAlreadyAvailableToUser) return null;
    // Once a mission is accepted, the transmission that revealed it has
    // necessarily already played — nothing left to remind about.
    if (missionAlreadyAccepted) return null;
    if (_shownToday(lastShownAt, localNow)) return null;

    final dedupKey = 'daily_transmission:${_dateKey(localNow)}';
    return ForgeNotification(
      id: dedupKey,
      type: ForgeNotificationType.dailyTransmission,
      dedupKey: dedupKey,
      createdAt: localNow,
      readAt: null,
      metadata: const {},
    );
  }

  static ForgeNotification? missionFollowupReminder({
    required NotificationPreferences preferences,
    required DateTime localNow,
    required DateTime? lastShownAt,
    required DateTime acceptedAt,
    required String missionInstanceId,
    required String missionTitle,
    required bool missionCompleted,
  }) {
    if (_blockedByPreferencesOrQuietHours(
      preferences: preferences,
      categoryEnabled: preferences.missionFollowupEnabled,
      localNow: localNow,
    )) {
      return null;
    }
    // Never nag about a mission the user already finished — the single
    // most important rule in this file (spec section 16: "no follow-up
    // for already-completed mission").
    if (missionCompleted) return null;
    if (localNow.difference(acceptedAt) < followupMinimumAge) return null;
    if (lastShownAt != null && localNow.difference(lastShownAt) < followupCooldown) {
      return null;
    }

    final dedupKey = 'mission_followup:$missionInstanceId';
    return ForgeNotification(
      id: dedupKey,
      type: ForgeNotificationType.missionFollowup,
      dedupKey: dedupKey,
      createdAt: localNow,
      readAt: null,
      metadata: {'missionInstanceId': missionInstanceId, 'missionTitle': missionTitle},
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
