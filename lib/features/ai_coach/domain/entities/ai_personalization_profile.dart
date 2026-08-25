import 'package:flutter/foundation.dart';

import '../enums/coaching_tone.dart';

/// Explicit, user-set preferences (Roadmap Item 14 section 6) — every
/// field here is something the user picked from a fixed list in a
/// settings screen, never something inferred from behavior. Contrast
/// with [AiCoachContext.consistencySummary]/`isRecoveryMode`, which
/// *are* behavior-derived but computed entirely by Forge's existing
/// deterministic engines, never by this profile or by the AI itself.
@immutable
class AiPersonalizationProfile {
  const AiPersonalizationProfile({
    this.coachingTone = CoachingTone.calm,
    this.preferredChallengeStyle = PreferredChallengeStyle.steady,
    this.preferredCategories = const [],
    this.dislikedCategories = const [],
    this.dailyTimeBudgetMinutes,
    this.goalFocus,
    this.explanationDepth = ExplanationDepth.standard,
  });

  final CoachingTone coachingTone;
  final PreferredChallengeStyle preferredChallengeStyle;
  final List<String> preferredCategories;
  final List<String> dislikedCategories;
  final int? dailyTimeBudgetMinutes;
  final GoalFocus? goalFocus;
  final ExplanationDepth explanationDepth;

  AiPersonalizationProfile copyWith({
    CoachingTone? coachingTone,
    PreferredChallengeStyle? preferredChallengeStyle,
    List<String>? preferredCategories,
    List<String>? dislikedCategories,
    int? dailyTimeBudgetMinutes,
    GoalFocus? goalFocus,
    ExplanationDepth? explanationDepth,
  }) {
    return AiPersonalizationProfile(
      coachingTone: coachingTone ?? this.coachingTone,
      preferredChallengeStyle:
          preferredChallengeStyle ?? this.preferredChallengeStyle,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      dislikedCategories: dislikedCategories ?? this.dislikedCategories,
      dailyTimeBudgetMinutes:
          dailyTimeBudgetMinutes ?? this.dailyTimeBudgetMinutes,
      goalFocus: goalFocus ?? this.goalFocus,
      explanationDepth: explanationDepth ?? this.explanationDepth,
    );
  }
}
