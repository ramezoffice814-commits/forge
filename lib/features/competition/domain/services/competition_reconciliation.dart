import 'package:flutter/foundation.dart';

/// A server-confirmed competitive-score contribution — deliberately its
/// own type, never merged into [WeeklyCompetitionScore] (which stays
/// `provisionalOnly` by construction; see that entity's own doc
/// comment). Keeping this separate is what makes "lifetime XP !=
/// competition score" *and* "provisional vs. confirmed competition data"
/// both structurally obvious at the type level, matching how
/// [MissionSubmissionServerResult.competitionScoreUpdate] already
/// arrives wrapped as an [AuthoritativeValue] rather than a bare double.
///
/// Known scope limit (see supabase/README.md and the Phase 10D final
/// report): this phase records the confirmed contribution for display
/// and audit, but does not yet feed it back into
/// `CurrentCompetitionState`'s live ranking recomputation — that state
/// is always freshly re-derived from local provisional data
/// (`CompetitionRepository`), and a real confirmed-leaderboard read
/// model (`competition_public_leaderboard`, added this phase) is the
/// intended eventual replacement for that local recompute, not a patch
/// applied on top of it.
@immutable
class ConfirmedCompetitionContribution {
  const ConfirmedCompetitionContribution({
    required this.missionInstanceId,
    required this.confirmedScoreDelta,
    required this.integrityStatus,
    required this.confirmedAt,
  });

  final String missionInstanceId;
  final double confirmedScoreDelta;
  final String integrityStatus;
  final DateTime confirmedAt;
}

abstract final class CompetitionReconciliation {
  /// Pure accumulation of confirmed contributions this session — never
  /// derives a value from provisional local score, and never lets a
  /// provisional recompute silently erase a confirmation already
  /// recorded here.
  static List<ConfirmedCompetitionContribution> appendConfirmed(
    List<ConfirmedCompetitionContribution> current,
    ConfirmedCompetitionContribution next,
  ) {
    if (current.any((c) => c.missionInstanceId == next.missionInstanceId)) {
      return current; // idempotent — a replayed confirmation is a no-op.
    }
    return [...current, next];
  }

  static double totalConfirmedScore(
    List<ConfirmedCompetitionContribution> confirmed,
  ) {
    return confirmed.fold<double>(0, (sum, c) => sum + c.confirmedScoreDelta);
  }
}
