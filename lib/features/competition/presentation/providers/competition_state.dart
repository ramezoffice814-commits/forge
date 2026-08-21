import 'package:flutter/foundation.dart';

import '../../domain/entities/hall_of_fame_record.dart';
import '../../domain/entities/public_leaderboard_entry.dart';
import '../../domain/services/cached_leaderboard_fetch.dart';
import '../../domain/services/competition_reconciliation.dart';
import '../../domain/usecases/get_current_competition_state_usecase.dart';
import '../../domain/usecases/get_season_progress_usecase.dart';

@immutable
sealed class CompetitionState {
  const CompetitionState();
}

class CompetitionLoading extends CompetitionState {
  const CompetitionLoading();
}

class CompetitionError extends CompetitionState {
  const CompetitionError(this.message);

  final String message;
}

/// Which of [CompetitionReady]'s two "score" numbers is currently the
/// more trustworthy one to lead with in UI copy — never a claim that
/// the provisional number has become confirmed (spec section 8:
/// "server-confirmed leaderboard state wins over local preview").
enum CompetitionAuthorityStatus {
  /// No confirmed weekly leaderboard row has been fetched yet this
  /// session — only the local provisional preview exists.
  provisionalOnly,

  /// A confirmed weekly standing has been fetched and is the freshest
  /// authority available.
  confirmed,

  /// A confirmed standing exists but is from a prior fetch that failed
  /// to refresh — still shown, but visibly stale (spec: "local preview
  /// may still be displayed as an estimate when fresher than last
  /// sync").
  confirmedStale,
}

class CompetitionReady extends CompetitionState {
  const CompetitionReady({
    required this.current,
    required this.hallOfFame,
    required this.seasonProgress,
    this.confirmedContributions = const [],
    this.confirmedWeeklyStanding,
    this.confirmedWeeklyStandingFreshness = LeaderboardFreshness.unavailable,
  });

  final CurrentCompetitionState current;
  final List<HallOfFameRecord> hallOfFame;
  final SeasonProgressSnapshot seasonProgress;

  /// Server-confirmed per-mission competitive-score contributions this
  /// session (spec section 11 — Phase 10D). Deliberately separate from
  /// [current]'s `weeklyScore` (which stays local-provisional-only,
  /// re-derived fresh every refresh) — see
  /// `ConfirmedCompetitionContribution`'s own doc comment for why these
  /// two are not yet merged into one live number.
  final List<ConfirmedCompetitionContribution> confirmedContributions;

  double get totalConfirmedScore =>
      CompetitionReconciliation.totalConfirmedScore(confirmedContributions);

  /// The caller's own row from the confirmed weekly leaderboard fetch
  /// (spec section 8's "confirmed weekly score, confirmed league,
  /// confirmed rank") — `null` until at least one successful or
  /// previously-cached fetch has happened.
  final PublicWeeklyLeaderboardEntry? confirmedWeeklyStanding;
  final LeaderboardFreshness confirmedWeeklyStandingFreshness;

  CompetitionAuthorityStatus get authorityStatus =>
      resolveCompetitionAuthorityStatus(
        hasConfirmedStanding: confirmedWeeklyStanding != null,
        freshness: confirmedWeeklyStandingFreshness,
      );
}

/// Pure decision logic behind [CompetitionReady.authorityStatus] — split
/// out so it's directly unit-testable without constructing a full
/// [CompetitionReady]/[CurrentCompetitionState] (spec section 23:
/// "confirmed score overriding provisional rank").
CompetitionAuthorityStatus resolveCompetitionAuthorityStatus({
  required bool hasConfirmedStanding,
  required LeaderboardFreshness freshness,
}) {
  if (!hasConfirmedStanding) {
    return CompetitionAuthorityStatus.provisionalOnly;
  }
  return freshness == LeaderboardFreshness.cachedStale
      ? CompetitionAuthorityStatus.confirmedStale
      : CompetitionAuthorityStatus.confirmed;
}
