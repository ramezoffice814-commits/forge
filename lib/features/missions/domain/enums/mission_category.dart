/// The fixed set of mission categories the catalog can draw from. Closed
/// (not open string tags) so every policy can exhaustively switch over it —
/// a new category is a deliberate catalog/engine change, never something a
/// mission author can invent inline.
enum MissionCategory {
  fitness,
  coding,
  reading,
  learning,
  mindfulness,
  hydration,
  planning,
  focus,
  sleepRoutine,
  recovery,
  creative,
  socialWellbeing,
}

String missionCategoryLabel(MissionCategory category) {
  return switch (category) {
    MissionCategory.fitness => 'Fitness',
    MissionCategory.coding => 'Coding',
    MissionCategory.reading => 'Reading',
    MissionCategory.learning => 'Learning',
    MissionCategory.mindfulness => 'Mindfulness',
    MissionCategory.hydration => 'Hydration',
    MissionCategory.planning => 'Planning',
    MissionCategory.focus => 'Focus',
    MissionCategory.sleepRoutine => 'Sleep Routine',
    MissionCategory.recovery => 'Recovery',
    MissionCategory.creative => 'Creative',
    MissionCategory.socialWellbeing => 'Social Wellbeing',
  };
}
