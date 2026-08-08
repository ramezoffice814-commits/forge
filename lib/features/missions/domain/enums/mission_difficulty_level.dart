/// Five-level difficulty scale used internally by the selection engine —
/// finer-grained than the Dashboard/Transmission UI's existing 3-level
/// `MissionDifficulty` (easy/moderate/hard), which an adapter in the data
/// layer maps down to so no existing widget needs to change. Declaration
/// order is the ordinal order: comparisons use `.index` directly (e.g. "at
/// most one level up" is `next.index - current.index <= 1`).
enum MissionDifficultyLevel {
  restorative,
  easy,
  moderate,
  challenging,
  advanced,
}

extension MissionDifficultyLevelOrdinal on MissionDifficultyLevel {
  bool isAtMost(MissionDifficultyLevel other) => index <= other.index;
  bool isAtLeast(MissionDifficultyLevel other) => index >= other.index;

  MissionDifficultyLevel get oneLevelUp {
    final nextIndex = index + 1;
    if (nextIndex >= MissionDifficultyLevel.values.length) return this;
    return MissionDifficultyLevel.values[nextIndex];
  }

  MissionDifficultyLevel get oneLevelDown {
    final prevIndex = index - 1;
    if (prevIndex < 0) return this;
    return MissionDifficultyLevel.values[prevIndex];
  }
}

String missionDifficultyLevelLabel(MissionDifficultyLevel level) {
  return switch (level) {
    MissionDifficultyLevel.restorative => 'Restorative',
    MissionDifficultyLevel.easy => 'Easy',
    MissionDifficultyLevel.moderate => 'Moderate',
    MissionDifficultyLevel.challenging => 'Challenging',
    MissionDifficultyLevel.advanced => 'Advanced',
  };
}
