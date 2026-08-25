import 'package:flutter/foundation.dart';

import 'quiet_hours.dart';

/// Client-owned (`trust_boundary.dart`): the user is the sole source of
/// truth for every field here. Persisted server-side via
/// `notification_preferences` (own-row RLS) purely for cross-device
/// sync and structurally-enforced account-switch isolation — not
/// because the server has any opinion about these values.
///
/// Deliberately a separate type from `AiPersonalizationProfile`/
/// `AiPrivacyLevel` (Roadmap Item 14) — notification preferences and AI
/// context privacy are unrelated concerns that happen to both be
/// per-user settings; coupling them would make disabling one silently
/// affect the other.
@immutable
class NotificationPreferences {
  const NotificationPreferences({
    this.masterEnabled = true,
    this.dailyMissionEnabled = true,
    this.dailyTransmissionEnabled = true,
    this.missionFollowupEnabled = true,
    this.achievementEnabled = true,
    this.progressionEnabled = true,
    this.weeklyRecapEnabled = true,
    this.competitionResultEnabled = true,
    // Opt-in, not opt-out (spec section 4H: "no manipulative come-back
    // spam" — a user who never turns this on never gets one).
    this.reEngagementEnabled = false,
    this.quietHours = const QuietHours(enabled: false, startMinute: 1350, endMinute: 420),
    this.timezone = 'UTC',
  });

  final bool masterEnabled;
  final bool dailyMissionEnabled;
  final bool dailyTransmissionEnabled;
  final bool missionFollowupEnabled;
  final bool achievementEnabled;
  final bool progressionEnabled;
  final bool weeklyRecapEnabled;
  final bool competitionResultEnabled;
  final bool reEngagementEnabled;
  final QuietHours quietHours;

  /// IANA identifier from the device (e.g. "Africa/Cairo") — stored so
  /// a future server-side scheduler could use it; never assumed to be
  /// UTC (spec section 9).
  final String timezone;

  NotificationPreferences copyWith({
    bool? masterEnabled,
    bool? dailyMissionEnabled,
    bool? dailyTransmissionEnabled,
    bool? missionFollowupEnabled,
    bool? achievementEnabled,
    bool? progressionEnabled,
    bool? weeklyRecapEnabled,
    bool? competitionResultEnabled,
    bool? reEngagementEnabled,
    QuietHours? quietHours,
    String? timezone,
  }) {
    return NotificationPreferences(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      dailyMissionEnabled: dailyMissionEnabled ?? this.dailyMissionEnabled,
      dailyTransmissionEnabled: dailyTransmissionEnabled ?? this.dailyTransmissionEnabled,
      missionFollowupEnabled: missionFollowupEnabled ?? this.missionFollowupEnabled,
      achievementEnabled: achievementEnabled ?? this.achievementEnabled,
      progressionEnabled: progressionEnabled ?? this.progressionEnabled,
      weeklyRecapEnabled: weeklyRecapEnabled ?? this.weeklyRecapEnabled,
      competitionResultEnabled: competitionResultEnabled ?? this.competitionResultEnabled,
      reEngagementEnabled: reEngagementEnabled ?? this.reEngagementEnabled,
      quietHours: quietHours ?? this.quietHours,
      timezone: timezone ?? this.timezone,
    );
  }
}
