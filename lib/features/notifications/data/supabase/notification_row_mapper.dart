import '../../domain/entities/forge_notification.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/entities/quiet_hours.dart';
import '../../domain/enums/forge_notification_type.dart';

/// Plain, network-free row parsing — mirrors
/// `leaderboard_row_mapper.dart`'s own separation from the Supabase
/// query itself. A row with an unrecognized `type` is dropped rather
/// than throwing (the same "never guess, never crash on an unexpected
/// shape" posture `AiCoachSuggestedAction.tryParse` uses) — forward-
/// compatible with a server that has learned a new type this client
/// build doesn't know about yet.
ForgeNotification? parseNotificationRow(Map<String, dynamic> row) {
  final type = ForgeNotificationType.tryParse(row['type'] as String? ?? '');
  if (type == null) return null;

  final metadata = row['metadata'];
  return ForgeNotification(
    id: row['id'] as String,
    type: type,
    dedupKey: row['dedup_key'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    readAt: row['read_at'] == null ? null : DateTime.parse(row['read_at'] as String),
    metadata: metadata is Map<String, dynamic> ? metadata : const {},
  );
}

NotificationPreferences parsePreferencesRow(Map<String, dynamic> row) {
  return NotificationPreferences(
    masterEnabled: row['master_enabled'] as bool? ?? true,
    dailyMissionEnabled: row['daily_mission_enabled'] as bool? ?? true,
    dailyTransmissionEnabled: row['daily_transmission_enabled'] as bool? ?? true,
    missionFollowupEnabled: row['mission_followup_enabled'] as bool? ?? true,
    achievementEnabled: row['achievement_enabled'] as bool? ?? true,
    progressionEnabled: row['progression_enabled'] as bool? ?? true,
    weeklyRecapEnabled: row['weekly_recap_enabled'] as bool? ?? true,
    competitionResultEnabled: row['competition_result_enabled'] as bool? ?? true,
    reEngagementEnabled: row['re_engagement_enabled'] as bool? ?? false,
    quietHours: QuietHours(
      enabled: row['quiet_hours_enabled'] as bool? ?? false,
      startMinute: row['quiet_hours_start_minute'] as int? ?? 1350,
      endMinute: row['quiet_hours_end_minute'] as int? ?? 420,
    ),
    timezone: row['timezone'] as String? ?? 'UTC',
  );
}

Map<String, Object?> preferencesToRow(NotificationPreferences preferences) {
  return {
    'master_enabled': preferences.masterEnabled,
    'daily_mission_enabled': preferences.dailyMissionEnabled,
    'daily_transmission_enabled': preferences.dailyTransmissionEnabled,
    'mission_followup_enabled': preferences.missionFollowupEnabled,
    'achievement_enabled': preferences.achievementEnabled,
    'progression_enabled': preferences.progressionEnabled,
    'weekly_recap_enabled': preferences.weeklyRecapEnabled,
    'competition_result_enabled': preferences.competitionResultEnabled,
    're_engagement_enabled': preferences.reEngagementEnabled,
    'quiet_hours_enabled': preferences.quietHours.enabled,
    'quiet_hours_start_minute': preferences.quietHours.startMinute,
    'quiet_hours_end_minute': preferences.quietHours.endMinute,
    'timezone': preferences.timezone,
  };
}
