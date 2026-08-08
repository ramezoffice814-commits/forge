import '../entities/level_definition.dart';

/// Deterministic level lookup over a plain, ordered catalog — deliberately
/// no if/else chain, so extending the ladder is purely a catalog change
/// (see spec section 7: "supports future level expansion").
abstract final class LevelPolicy {
  static List<LevelDefinition> _sorted(List<LevelDefinition> catalog) =>
      [...catalog]..sort((a, b) => a.requiredXp.compareTo(b.requiredXp));

  /// The highest level whose `requiredXp` is met by [totalXp]. Falls back
  /// to the catalog's lowest level if [totalXp] is somehow below even that
  /// (e.g. an empty/misconfigured catalog is the caller's bug, not this
  /// method's to hide).
  static LevelDefinition levelFor(int totalXp, List<LevelDefinition> catalog) {
    assert(catalog.isNotEmpty, 'Level catalog must not be empty.');
    final sorted = _sorted(catalog);
    var current = sorted.first;
    for (final level in sorted) {
      if (totalXp >= level.requiredXp) {
        current = level;
      } else {
        break;
      }
    }
    return current;
  }

  /// `null` once [current] is already the top of the catalog.
  static LevelDefinition? nextLevel(
    LevelDefinition current,
    List<LevelDefinition> catalog,
  ) {
    final sorted = _sorted(catalog);
    final index = sorted.indexWhere(
      (l) => l.levelNumber == current.levelNumber,
    );
    if (index == -1 || index + 1 >= sorted.length) return null;
    return sorted[index + 1];
  }

  /// 0–1 progress from [current] toward [nextLevel]; `1.0` at the top level.
  static double progressToNextLevel(
    int totalXp,
    List<LevelDefinition> catalog,
  ) {
    final current = levelFor(totalXp, catalog);
    final next = nextLevel(current, catalog);
    if (next == null) return 1.0;
    final span = next.requiredXp - current.requiredXp;
    if (span <= 0) return 1.0;
    return ((totalXp - current.requiredXp) / span).clamp(0, 1);
  }

  /// `0` at the top level.
  static int xpToNextLevel(int totalXp, List<LevelDefinition> catalog) {
    final next = nextLevel(levelFor(totalXp, catalog), catalog);
    if (next == null) return 0;
    return (next.requiredXp - totalXp).clamp(0, next.requiredXp);
  }
}
