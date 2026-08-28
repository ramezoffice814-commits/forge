import '../../domain/entities/mission_history_snapshot.dart';
import '../../domain/entities/user_title.dart';

/// Behavior-earned cosmetic titles — separate from the level ladder (see
/// `TitlePolicy`'s doc comment). Every one is forward-framed; there is
/// intentionally no title tied to inactivity or underperformance.
abstract final class TitleCatalog {
  /// Always matches — the baseline used both as a real catalog entry and as
  /// `TitlePolicy.evaluate`'s `fallback`.
  static const starter = UserTitleDefinition(
    id: 'the_starter',
    name: 'The Starter',
    description: 'Showed up and began.',
    priority: 0,
    matches: _alwaysTrue,
  );

  static bool _alwaysTrue(MissionHistorySnapshot snapshot) => true;

  static List<UserTitleDefinition> build() => [
    starter,
    UserTitleDefinition(
      id: 'the_builder',
      name: 'The Builder',
      description: 'Ten missions in — a real habit taking shape.',
      priority: 10,
      matches: (s) => s.totalCompletions >= 10,
    ),
    UserTitleDefinition(
      id: 'the_explorer',
      name: 'The Explorer',
      description: 'Willing to try almost anything CAN offers.',
      priority: 10,
      matches: (s) => s.categoriesTried.length >= 4,
    ),
    UserTitleDefinition(
      id: 'the_consistent',
      name: 'The Consistent',
      description: 'A full week without missing a day.',
      priority: 20,
      matches: (s) => s.currentStreakDays >= 7,
    ),
    UserTitleDefinition(
      id: 'the_architect',
      name: 'The Architect',
      description: 'Chose the hard missions, repeatedly.',
      priority: 30,
      matches: (s) => s.advancedOrChallengingCompletions >= 10,
    ),
  ];
}
