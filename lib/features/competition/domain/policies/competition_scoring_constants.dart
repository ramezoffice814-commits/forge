/// Every magic number the competition module uses, in one versioned place.
/// Nothing in this feature should hardcode a cap, factor, or threshold
/// inline — see spec section 10's "never scatter magic values across code."
abstract final class CompetitionScoringConstants {
  /// Bumped whenever `ForgeCompetitiveScorePolicy`'s formula changes.
  static const int scoringVersion = 1;
  static const int leagueRulesVersion = 1;
  static const int promotionRulesVersion = 1;

  // --- Per-mission base score -------------------------------------------
  static const double baseCompletionScore = 10.0;

  static const Map<String, double> difficultyFactors = {
    'restorative': 0.6,
    'easy': 0.8,
    'moderate': 1.0,
    'challenging': 1.3,
    'advanced': 1.6,
  };

  static const Map<String, double> qualityFactors = {
    'low': 0.7,
    'standard': 1.0,
    'high': 1.15,
  };

  // --- Diversity (section 11) --------------------------------------------
  /// Multiplier applied the first time a category is used in a week.
  static const double diversityNewCategoryBonus = 1.1;

  /// Floor multiplier for a category already used many times this week —
  /// diminishing, never punitive (never below this).
  static const double diversityDominantCategoryFloor = 0.85;

  /// After this many completions in the same category within one week,
  /// each additional completion in it nudges toward
  /// [diversityDominantCategoryFloor].
  static const int diversityDominanceThreshold = 4;

  // --- Consistency (section 12) ------------------------------------------
  /// Consistency bonus is capped at this fraction of the week's raw score
  /// — "missing one day must not destroy the week", but it also can never
  /// dominate the score.
  static const double maxConsistencyBonusFraction = 0.08;

  // --- Repetition penalty (fairness) -------------------------------------
  /// Each repeat of the same mission family within the look-back window
  /// multiplies remaining value by this factor (compounding), so identical
  /// easy-mission farming has sharply diminishing returns.
  static const double repetitionDecayFactor = 0.6;

  // --- Recovery normalization (section 13) --------------------------------
  /// A recovery mission's per-mission score is capped at this fraction of
  /// what the same difficulty would score normally — "no advantage, no
  /// humiliation": still meaningfully rewarded, never competitively equal
  /// to a normal mission of the same difficulty.
  static const double recoveryScoreCapFraction = 0.5;

  // --- Caps (section 10) ---------------------------------------------------
  static const double maxScorePerMission = 25.0;
  static const double maxScorePerCategoryPerDay = 40.0;
  static const double maxScorePerDay = 80.0;
  static const double maxScorePerWeek = 400.0;

  // --- Rookie placement (section 6) ---------------------------------------
  static const int rookieProtectionDays = 14;
  static const int rookieProtectionCompletions = 10;

  // --- Inactivity (section 20) ---------------------------------------------
  /// Consecutive fully-inactive weeks after which a participant is excluded
  /// from the active leaderboard pool (lifetime XP is never touched).
  static const int inactivityExclusionWeeks = 3;

  // --- Season aggregation (section 15) -------------------------------------
  /// Default "best N of M" — overridden per-season via
  /// `SeasonDefinition.weekCount` and `SeasonScoringPolicy.countedWeeksFor`.
  static const int defaultSeasonWeekCount = 8;
  static const int defaultSeasonCountedWeeks = 6;

  // --- Integrity (section 33) ----------------------------------------------
  /// A single completion within this many seconds of the previous one for
  /// the same user is flagged as an impossible-sequence signal.
  static const int impossibleSequenceMinSeconds = 20;

  /// More than this many scoring completions in one UTC day is flagged as
  /// excessive volume.
  static const int excessiveDailyVolumeThreshold = 12;

  /// Repeated-mission-family count at or above this is flagged as farming.
  static const int repeatedFarmingThreshold = 5;
}
