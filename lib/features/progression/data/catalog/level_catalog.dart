import '../../domain/entities/level_definition.dart';

/// Generated (not hand-enumerated) so extending the ladder later is a
/// one-line change to [maxLevel] or the milestone map — never a rewrite
/// (spec section 7: "supports future level expansion", "no hardcoded
/// if/else chains").
abstract final class LevelCatalog {
  static const maxLevel = 30;

  /// Level -> rank title, holding steady until the next milestone. Product
  /// placeholders only — no real-world status implied.
  static const _milestoneTitles = <int, String>{
    1: 'Forge Initiate',
    5: 'Builder',
    10: 'Architect',
    20: 'Forge Master',
  };

  static const _milestoneDescriptions = <int, String>{
    1: 'Just getting the forge lit.',
    5: 'Turning up consistently, one mission at a time.',
    10: 'Shaping real structure out of daily effort.',
    20: 'Discipline that speaks for itself.',
  };

  static List<LevelDefinition> build() {
    return [
      for (var level = 1; level <= maxLevel; level++)
        LevelDefinition(
          levelNumber: level,
          requiredXp: _requiredXpFor(level),
          title: _lookupMilestone(_milestoneTitles, level),
          description: _lookupMilestone(_milestoneDescriptions, level),
          unlocks: _milestoneTitles.containsKey(level)
              ? ['New Watcher dialogue at level $level']
              : const [],
        ),
    ];
  }

  /// A smooth, ever-increasing curve rather than a hand-typed table per
  /// level — level 1 is always free (`requiredXp == 0`).
  static int _requiredXpFor(int level) {
    if (level <= 1) return 0;
    return 25 * (level - 1) * level;
  }

  static String _lookupMilestone(Map<int, String> milestones, int level) {
    var result = milestones[1]!;
    for (final entry in milestones.entries) {
      if (level >= entry.key) result = entry.value;
    }
    return result;
  }
}
