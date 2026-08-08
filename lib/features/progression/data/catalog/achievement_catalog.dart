import '../../../missions/domain/enums/mission_category.dart';
import '../../../missions/domain/enums/mission_difficulty_level.dart';
import '../../domain/entities/achievement_definition.dart';

/// Curated, hand-authored achievements — every one earned through ordinary,
/// healthy behavior patterns. Deliberately excludes anything resembling an
/// extreme-volume or punishment-based achievement (spec section 10's
/// explicit warning) — nothing here rewards overtraining, sleep
/// deprivation, or any single-day extreme.
abstract final class AchievementCatalog {
  static List<AchievementDefinition> build() => [
    const AchievementDefinition(
      id: 'first_mission',
      name: 'First Steps',
      description: 'Complete your first mission.',
      category: AchievementCategory.consistency,
      criteria: TotalCompletionsCriteria(1),
      rarity: AchievementRarity.common,
      iconId: 'first_mission',
    ),
    const AchievementDefinition(
      id: 'momentum_3_day',
      name: 'Momentum',
      description: 'Maintain a 3-day streak.',
      category: AchievementCategory.consistency,
      criteria: StreakCriteria(3),
      rarity: AchievementRarity.common,
      iconId: 'momentum_3_day',
    ),
    const AchievementDefinition(
      id: 'consistency_7_day',
      name: 'Steady Hands',
      description: 'Maintain a 7-day streak.',
      category: AchievementCategory.consistency,
      criteria: StreakCriteria(7),
      rarity: AchievementRarity.uncommon,
      iconId: 'consistency_7_day',
    ),
    const AchievementDefinition(
      id: 'tried_3_categories',
      name: 'Curious Mind',
      description: 'Try 3 different mission categories.',
      category: AchievementCategory.exploration,
      criteria: CategoryVarietyCriteria(3),
      rarity: AchievementRarity.common,
      iconId: 'tried_3_categories',
    ),
    AchievementDefinition(
      id: 'tried_all_categories',
      name: 'Full Spectrum',
      description: 'Try every mission category at least once.',
      category: AchievementCategory.exploration,
      criteria: CategoryVarietyCriteria(MissionCategory.values.length),
      rarity: AchievementRarity.epic,
      iconId: 'tried_all_categories',
      hiddenUntilUnlocked: true,
    ),
    const AchievementDefinition(
      id: 'coding_10',
      name: 'Code Momentum',
      description: 'Complete 10 coding missions.',
      category: AchievementCategory.skill,
      criteria: CategoryCompletionsCriteria(
        category: MissionCategory.coding,
        target: 10,
      ),
      rarity: AchievementRarity.uncommon,
      iconId: 'coding_10',
    ),
    const AchievementDefinition(
      id: 'reading_10',
      name: 'Bookworm',
      description: 'Complete 10 reading missions.',
      category: AchievementCategory.skill,
      criteria: CategoryCompletionsCriteria(
        category: MissionCategory.reading,
        target: 10,
      ),
      rarity: AchievementRarity.uncommon,
      iconId: 'reading_10',
    ),
    const AchievementDefinition(
      id: 'fitness_10',
      name: 'Iron Habit',
      description: 'Complete 10 fitness missions.',
      category: AchievementCategory.skill,
      criteria: CategoryCompletionsCriteria(
        category: MissionCategory.fitness,
        target: 10,
      ),
      rarity: AchievementRarity.uncommon,
      iconId: 'fitness_10',
    ),
    const AchievementDefinition(
      id: 'returned_from_break',
      name: 'Welcome Back',
      description: 'Returned to a mission after some time away.',
      category: AchievementCategory.recovery,
      criteria: ReturnedFromInactivityCriteria(),
      rarity: AchievementRarity.rare,
      iconId: 'returned_from_break',
      hiddenUntilUnlocked: true,
    ),
    const AchievementDefinition(
      id: 'recovery_5',
      name: 'Gentle Progress',
      description: 'Complete 5 recovery missions.',
      category: AchievementCategory.recovery,
      criteria: RecoveryCompletionsCriteria(5),
      rarity: AchievementRarity.uncommon,
      iconId: 'recovery_5',
    ),
    const AchievementDefinition(
      id: 'advanced_10',
      name: 'Pushing Limits',
      description: 'Complete 10 challenging-or-above missions.',
      category: AchievementCategory.mastery,
      criteria: DifficultyCompletionsCriteria(
        minimumDifficulty: MissionDifficultyLevel.challenging,
        target: 10,
      ),
      rarity: AchievementRarity.rare,
      iconId: 'advanced_10',
    ),
    const AchievementDefinition(
      id: 'mastery_50_total',
      name: 'Forged in Repetition',
      description: 'Complete 50 missions total.',
      category: AchievementCategory.mastery,
      criteria: TotalCompletionsCriteria(50),
      rarity: AchievementRarity.epic,
      iconId: 'mastery_50_total',
    ),
  ];
}
