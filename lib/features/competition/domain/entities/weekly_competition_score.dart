import 'package:flutter/foundation.dart';

import '../../../missions/domain/enums/mission_category.dart';
import '../enums/integrity_signal.dart';

/// One participant's fully-aggregated weekly competitive standing —
/// ranking always uses [cappedScore], never [rawScore] (which exists only
/// so the UI/tests can show how much of a participant's activity was
/// actually capped away).
@immutable
class WeeklyCompetitionScore {
  const WeeklyCompetitionScore({
    required this.userId,
    required this.seasonId,
    required this.weekNumber,
    required this.rawScore,
    required this.cappedScore,
    required this.completedMissionCount,
    required this.activeDays,
    required this.categoriesUsed,
    required this.integrityFlags,
    required this.scoreBreakdown,
    this.provisionalOnly = true,
  });

  final String userId;
  final String seasonId;
  final int weekNumber;

  final double rawScore;
  final double cappedScore;

  final int completedMissionCount;

  /// Distinct calendar days (UTC) with at least one scoring completion —
  /// the input to `CompetitionConsistencyPolicy`, never a streak counter.
  final int activeDays;

  final Set<MissionCategory> categoriesUsed;
  final Set<IntegritySignal> integrityFlags;

  /// Named contributions summing to [rawScore] before capping (e.g.
  /// `{'missions': 420.0, 'consistencyBonus': 18.0}`) — kept so the
  /// fairness-explanation UI never has to reverse-engineer the math.
  final Map<String, double> scoreBreakdown;

  final bool provisionalOnly;
}
