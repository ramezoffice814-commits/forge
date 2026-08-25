import '../entities/forge_notification.dart';
import '../enums/forge_notification_type.dart';

/// Deterministic, Forge-owned display copy (Roadmap Item 15 section 17:
/// "Notifications must work if AI privacy = disabled... Prefer
/// deterministic Forge-owned copy"). No AI Coach dependency anywhere in
/// this file — a future pass could let AI Coach *propose* alternate
/// wording the same way it proposes suggested actions elsewhere in this
/// app, but every notification must already have this fallback before
/// that's ever wired in, never the other way around.
abstract final class NotificationCopy {
  static ({String title, String body}) resolve(ForgeNotification notification) {
    final metadata = notification.metadata;
    return switch (notification.type) {
      ForgeNotificationType.dailyMission => (
        title: "Today's mission is ready",
        body: (metadata['missionTitle'] as String?) ?? 'A new mission is waiting for you.',
      ),
      ForgeNotificationType.dailyTransmission => (
        title: 'The Watcher has a transmission for you',
        body: "Today's briefing is ready whenever you are.",
      ),
      ForgeNotificationType.missionFollowup => (
        title: 'Still open',
        body: '"${metadata['missionTitle'] ?? 'Your mission'}" is still waiting — pick it back up '
            'whenever you\'re ready.',
      ),
      ForgeNotificationType.achievementUnlock => (
        title: 'Achievement unlocked',
        body: (metadata['title'] as String?) ?? 'You unlocked a new achievement.',
      ),
      ForgeNotificationType.levelUp => (
        title: 'Level up',
        body: 'You reached level ${metadata['newLevel'] ?? '?'}.',
      ),
      ForgeNotificationType.weekResult => (
        title: 'Your weekly result is in',
        body: _weekResultBody(metadata),
      ),
      ForgeNotificationType.seasonResult => (
        title: 'Season complete',
        body: _seasonResultBody(metadata),
      ),
      ForgeNotificationType.weeklyRecap => (
        title: 'Your weekly recap is ready',
        body: 'Active ${metadata['activeDays'] ?? 0} day(s) this week.',
      ),
    };
  }

  static String _weekResultBody(Map<String, Object?> metadata) {
    final status = metadata['promotionStatus'] as String?;
    final rank = metadata['rank'];
    return switch (status) {
      'promotionZone' => 'Rank $rank — you\'re in the promotion zone.',
      'demotionZone' => 'Rank $rank — you\'re in the demotion zone this week.',
      _ => 'Rank $rank this week.',
    };
  }

  static String _seasonResultBody(Map<String, Object?> metadata) {
    final promoted = metadata['promoted'] == true;
    final demoted = metadata['demoted'] == true;
    if (promoted) return 'You were promoted at the end of this season.';
    if (demoted) return 'You were moved down a league at the end of this season.';
    return 'Your final standing for the season is ready.';
  }
}
