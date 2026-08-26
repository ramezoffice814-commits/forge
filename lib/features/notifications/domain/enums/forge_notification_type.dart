/// Every notification Forge can ever produce (Roadmap Item 15) — closed
/// on purpose, exactly like `AiCoachTask`/`AiCoachSuggestedAction`: a new
/// type is a deliberate addition here plus a deep-link mapping and
/// deterministic copy, never a string a caller invents inline.
///
/// [dailyMission], [dailyTransmission], and [missionFollowup] are
/// CLIENT OWNED (see `lib/core/security/trust_boundary.dart`) — computed
/// locally from state the client already authoritatively has, never
/// persisted server-side. The rest are SERVER AUTHORITATIVE — created
/// exclusively by `forge_create_notification()` inside the same
/// transaction as the fact they describe (see the Item 15 migration).
enum ForgeNotificationType {
  dailyMission,
  dailyTransmission,
  missionFollowup,
  achievementUnlock,
  levelUp,
  weekResult,
  seasonResult,
  weeklyRecap;

  /// Server rows carry `wireName` (snake_case, matching the SQL `type`
  /// check constraint in the Item 15 migration) in their `type` column —
  /// this is the exact inverse, never a guess. Client-owned types never
  /// appear in a server row, but are included here too so parsing stays
  /// total over the whole enum.
  static ForgeNotificationType? tryParse(String raw) {
    for (final type in values) {
      if (type.wireName == raw) return type;
    }
    return null;
  }

  /// snake_case wire form — matches the SQL `notifications.type` check
  /// constraint exactly for the server-authoritative members; the
  /// client-owned members never cross the wire but get a consistent
  /// form anyway so this function is total.
  String get wireName => switch (this) {
    dailyMission => 'daily_mission',
    dailyTransmission => 'daily_transmission',
    missionFollowup => 'mission_followup',
    achievementUnlock => 'achievement_unlock',
    levelUp => 'level_up',
    weekResult => 'week_result',
    seasonResult => 'season_result',
    weeklyRecap => 'weekly_recap',
  };

  bool get isServerAuthoritative => switch (this) {
    dailyMission || dailyTransmission || missionFollowup => false,
    achievementUnlock ||
    levelUp ||
    weekResult ||
    seasonResult ||
    weeklyRecap => true,
  };
}
