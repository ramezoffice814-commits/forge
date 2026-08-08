import '../../../missions/domain/enums/mission_category.dart';
import 'competition_scoring_constants.dart';

/// Rewards balanced discipline without ever forcing a category the user
/// doesn't do — see spec section 11: no penalty for accessibility-driven
/// exclusions, no mandatory categories, only a mild bonus for trying a new
/// one and mild diminishing returns for one category dominating the week.
abstract final class CompetitionDiversityPolicy {
  /// [priorCompletionsInCategoryThisWeek] is the count *before* the
  /// completion currently being scored.
  static double factorFor({
    required MissionCategory category,
    required int priorCompletionsInCategoryThisWeek,
  }) {
    if (priorCompletionsInCategoryThisWeek == 0) {
      return CompetitionScoringConstants.diversityNewCategoryBonus;
    }

    if (priorCompletionsInCategoryThisWeek <
        CompetitionScoringConstants.diversityDominanceThreshold) {
      return 1.0;
    }

    // Beyond the dominance threshold, decay gently toward the floor rather
    // than dropping straight to it — the 5th completion in a category
    // should feel only slightly diminished, not suddenly punished.
    final overage =
        priorCompletionsInCategoryThisWeek -
        CompetitionScoringConstants.diversityDominanceThreshold;
    final decay = 0.03 * overage;
    final floor = CompetitionScoringConstants.diversityDominantCategoryFloor;
    return (1.0 - decay).clamp(floor, 1.0);
  }

  static String explain({
    required MissionCategory category,
    required int priorCompletionsInCategoryThisWeek,
  }) {
    if (priorCompletionsInCategoryThisWeek == 0) {
      return 'First ${missionCategoryLabel(category)} completion this week';
    }
    if (priorCompletionsInCategoryThisWeek <
        CompetitionScoringConstants.diversityDominanceThreshold) {
      return 'Balanced category usage';
    }
    return '${missionCategoryLabel(category)} used heavily this week — '
        'mild diminishing returns';
  }
}
