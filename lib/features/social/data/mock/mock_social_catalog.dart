import '../../domain/entities/activity_event.dart';
import '../../domain/entities/public_profile.dart';
import '../../domain/enums/activity_event_type.dart';

/// A deterministic 8-user mock population that can be sent friend
/// requests, accepted, and shown in the activity feed — no `Random()`, no
/// runtime variance, same reasoning as `MockCompetitionCatalog`.
abstract final class MockSocialCatalog {
  static final DateTime referenceInstant = DateTime.utc(2026, 8, 10, 9);

  static const List<
    ({String name, int level, String title, int achievements, String league})
  >
  _profiles = [
    (
      name: 'Aiko',
      level: 12,
      title: 'Steady Hand',
      achievements: 14,
      league: 'Steel',
    ),
    (
      name: 'Bram',
      level: 27,
      title: 'Proven Veteran',
      achievements: 31,
      league: 'Mythic',
    ),
    (
      name: 'Coral',
      level: 8,
      title: 'Early Riser',
      achievements: 6,
      league: 'Iron',
    ),
    (
      name: 'Dax',
      level: 19,
      title: 'Consistent',
      achievements: 22,
      league: 'Titanium',
    ),
    (
      name: 'Esi',
      level: 5,
      title: 'Newcomer',
      achievements: 3,
      league: 'Ember',
    ),
    (
      name: 'Finn',
      level: 15,
      title: 'Disciplined',
      achievements: 18,
      league: 'Obsidian',
    ),
    (
      name: 'Greta',
      level: 22,
      title: 'Focused',
      achievements: 25,
      league: 'Titanium',
    ),
    (
      name: 'Hiro',
      level: 9,
      title: 'Building Habits',
      achievements: 7,
      league: 'Iron',
    ),
  ];

  static List<String> get mockUserIds =>
      List.generate(_profiles.length, (i) => 'mock-social-$i');

  static PublicProfile? profileFor(String userId) {
    final index = _indexFor(userId);
    if (index == null) return null;
    final entry = _profiles[index];
    return PublicProfile(
      userId: userId,
      displayName: entry.name,
      level: entry.level,
      title: entry.title,
      achievementsCount: entry.achievements,
      league: entry.league,
      competitionSummary: '${entry.league} League (preview)',
    );
  }

  static List<ActivityEvent> activityFor(String userId) {
    final index = _indexFor(userId);
    if (index == null) return const [];
    final entry = _profiles[index];

    return [
      ActivityEvent(
        id: '$userId-activity-1',
        userId: userId,
        displayName: entry.name,
        type: ActivityEventType.levelReached,
        headline: '${entry.name} reached level ${entry.level}',
        occurredAt: referenceInstant.subtract(const Duration(days: 1)),
      ),
      ActivityEvent(
        id: '$userId-activity-2',
        userId: userId,
        displayName: entry.name,
        type: ActivityEventType.achievementUnlocked,
        headline: '${entry.name} unlocked a new achievement',
        occurredAt: referenceInstant.subtract(const Duration(days: 3)),
      ),
      ActivityEvent(
        id: '$userId-activity-3',
        userId: userId,
        displayName: entry.name,
        type: ActivityEventType.competitionMilestone,
        headline: '${entry.name} reached ${entry.league} League',
        occurredAt: referenceInstant.subtract(const Duration(days: 5)),
      ),
    ];
  }

  static int? _indexFor(String userId) {
    if (!userId.startsWith('mock-social-')) return null;
    final index = int.tryParse(userId.substring('mock-social-'.length));
    if (index == null || index < 0 || index >= _profiles.length) return null;
    return index;
  }
}
