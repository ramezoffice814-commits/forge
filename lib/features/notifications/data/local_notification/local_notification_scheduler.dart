import '../../domain/entities/forge_notification.dart';
import '../../domain/entities/quiet_hours.dart';
import '../../domain/enums/forge_notification_type.dart';
import '../../domain/repositories/local_notification_service.dart';
import '../../domain/services/local_reminder_engine.dart';
import '../../domain/services/notification_copy.dart';

/// Translates already-decided Forge notification meaning into OS-level
/// calls (Roadmap Item 17) — never makes its own eligibility decisions.
/// [NotificationPreferences.allows]/[QuietHours.isQuietAt]/
/// [LocalReminderEngine] (all Roadmap Item 15) remain the only source of
/// "should this be shown"; this class only decides "how to hand an
/// already-approved reminder to the OS."
class LocalNotificationScheduler {
  const LocalNotificationScheduler(this._service);

  final LocalNotificationService _service;

  /// A stable, deterministic OS notification id derived from a Forge
  /// dedup key — never random (spec section 10), so recomputing the
  /// same logical reminder always maps to the same OS id, letting
  /// [LocalNotificationService.schedule] replace rather than duplicate
  /// it, and [LocalNotificationService.cancel] target it precisely.
  /// Masked to a positive 31-bit int — Android notification/request ids
  /// are plain `int`s and some platform codepaths reject negative ones.
  static int stableId(String dedupKey) => dedupKey.hashCode & 0x7fffffff;

  /// Mirrors whichever of [reminders] are already due — decided
  /// entirely by [LocalReminderEngine] before this is ever called (see
  /// `NotificationInboxController._computeLocalReminders`), including
  /// having already passed the quiet-hours/preference gate at that
  /// computation time. This method adds no eligibility logic of its
  /// own; it only presents. Mission Follow-up is deliberately excluded
  /// here — [syncMissionFollowup] owns its OS presentation via genuine
  /// advance scheduling instead, so a reminder that's *also* due right
  /// now doesn't get shown twice.
  Future<void> presentDueReminders(List<ForgeNotification> reminders) async {
    for (final reminder in reminders) {
      if (reminder.type == ForgeNotificationType.missionFollowup) continue;
      final copy = NotificationCopy.resolve(reminder);
      await _service.showNow(
        id: stableId(reminder.dedupKey),
        title: copy.title,
        body: copy.body,
        payload: reminder.type.wireName,
      );
    }
  }

  /// The one client-owned reminder with a genuinely future-dated,
  /// well-defined fire instant (`acceptedAt + LocalReminderEngine.
  /// followupMinimumAge`) — real advance [LocalNotificationService.
  /// schedule], deferred out of quiet hours via [QuietHours.
  /// nextEligibleTime] (spec section 9), rather than only ever mirroring
  /// "due right now" like [presentDueReminders] does for the other two
  /// reminder types. Cancels the prior schedule outright once the
  /// mission is completed, no longer accepted, or the category/master
  /// toggle turns off — the stable id means a repeat call with an
  /// updated fire time simply replaces what's already scheduled.
  Future<void> syncMissionFollowup({
    required String missionInstanceId,
    required String missionTitle,
    required DateTime? acceptedAt,
    required bool missionCompleted,
    required bool categoryEnabled,
    required bool masterEnabled,
    required QuietHours quietHours,
  }) async {
    final dedupKey = 'mission_followup:$missionInstanceId';
    final id = stableId(dedupKey);
    if (acceptedAt == null ||
        missionCompleted ||
        !categoryEnabled ||
        !masterEnabled) {
      await _service.cancel(id);
      return;
    }

    final dueAt = acceptedAt.add(LocalReminderEngine.followupMinimumAge);
    final fireAt = quietHours.nextEligibleTime(dueAt);
    final copy = NotificationCopy.resolve(
      ForgeNotification(
        id: dedupKey,
        type: ForgeNotificationType.missionFollowup,
        dedupKey: dedupKey,
        createdAt: fireAt,
        readAt: null,
        metadata: {
          'missionInstanceId': missionInstanceId,
          'missionTitle': missionTitle,
        },
      ),
    );
    await _service.schedule(
      id: id,
      scheduledAt: fireAt,
      title: copy.title,
      body: copy.body,
      payload: ForgeNotificationType.missionFollowup.wireName,
    );
  }

  /// Account-switch isolation (spec section 14): called on sign-out so
  /// no locally-scheduled OS reminder survives into the next signed-in
  /// user's session on the same device.
  Future<void> cancelAllForSignOut() => _service.cancelAll();
}
