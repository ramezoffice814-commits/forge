import 'package:flutter/foundation.dart';

import '../enums/coaching_tone.dart';

/// The complete, closed set of facts the AI Coach is ever allowed to see
/// — Roadmap Item 14 section 5. This class's field list **is** the
/// privacy contract: if a fact isn't a named field here, nothing in this
/// module can accidentally send it, because there is no path from a raw
/// domain entity (a full `MissionAggregate`, a `UserProgressionProfile`,
/// a `CompetitiveScoreEvaluation`) into a provider call that doesn't go
/// through this narrow, explicit shape first — the same "narrow bridge
/// object" pattern `CompletedMissionSummary`/`CompetitiveCompletionSummary`
/// already use between missions/progression/competition.
///
/// Deliberately never includes (see the module's own README-equivalent —
/// this doc comment): email, password, JWT/session tokens, idempotency
/// keys, integrity/anti-abuse signals, raw reflection text, health
/// limitations, full mission-event history, or any field not explicitly
/// named below. `AiCoachContextBuilder` is the only place instances of
/// this class are constructed from real app state — see that class for
/// how each field is derived and why the excluded ones are excluded.
@immutable
class AiCoachContext {
  const AiCoachContext({
    required this.displayName,
    required this.currentMissionTitle,
    required this.currentMissionCategory,
    required this.currentMissionDifficulty,
    required this.availableMinutesToday,
    required this.recentCompletionRatePercent,
    required this.activeDaysThisWeek,
    required this.currentLevel,
    required this.currentTitle,
    required this.currentLeagueName,
    required this.recentCategoryUsage,
    required this.consistencySummary,
    required this.isRecoveryMode,
    required this.preferredCategories,
    required this.dislikedCategories,
    required this.goalFocusLabel,
    required this.coachingTone,
    this.userMessage,
  });

  final String displayName;

  final String? currentMissionTitle;
  final String? currentMissionCategory;
  final String? currentMissionDifficulty;

  final int availableMinutesToday;

  /// A rounded aggregate (e.g. 0-100), never a raw completion log.
  final int recentCompletionRatePercent;
  final int activeDaysThisWeek;

  final int currentLevel;
  final String currentTitle;

  /// `null` if the user has no league placement yet (e.g. still in
  /// rookie placement) — never a raw numeric rank.
  final String? currentLeagueName;

  /// Broad category labels only (e.g. "fitness, reading"), never a
  /// per-mission breakdown.
  final List<String> recentCategoryUsage;

  /// A short, pre-composed phrase (e.g. "steady this week",
  /// "picking back up after a break") — never a raw streak counter or
  /// exact day-by-day log, so the AI narrates a *summary*, not a score.
  final String consistencySummary;

  /// Consumed as-is from deterministic app state (spec section 22: "AI
  /// must NOT infer recovery/medical state itself"). Never derived here.
  final bool isRecoveryMode;

  final List<String> preferredCategories;
  final List<String> dislikedCategories;
  final String? goalFocusLabel;

  final CoachingTone coachingTone;

  /// Only populated for [AiCoachTask.coachChat] — the user's own typed
  /// question. Free text, but it is what the user *chose* to send, not
  /// data collected about them; still never persisted longer than the
  /// active chat session (spec section 24).
  final String? userMessage;
}
