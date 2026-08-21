import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_state.dart';
import '../../../auth/presentation/auth_state_notifier.dart';
import '../../../missions/domain/entities/mission_instance.dart';
import '../../../progression/domain/entities/xp_reward_evaluation.dart';
import '../../domain/entities/competitive_completion_summary.dart';
import '../../domain/entities/public_leaderboard_entry.dart';
import '../../domain/enums/completion_quality.dart';
import '../../domain/enums/completion_validation_state.dart';
import '../../domain/enums/competition_integrity_state.dart';
import '../../domain/enums/reward_authority_state.dart';
import '../../domain/policies/competition_calendar.dart';
import '../../domain/services/competition_reconciliation.dart';
import 'competition_providers.dart';
import 'competition_state.dart';

/// The single authoritative competition session, mirroring
/// `ProgressionController`'s shape: a `ready` future callers await before
/// their first read, and one place (`reactToMissionCompletion`) that turns
/// a real mission completion into a recorded, scored competitive
/// completion — idempotent per mission instance, same as progression's own
/// reaction path.
class CompetitionController extends Notifier<CompetitionState> {
  final Completer<void> _readyCompleter = Completer<void>();
  final Set<String> _reactedMissionInstanceIds = {};

  /// Counts completions per mission *definition* (not instance) within
  /// this session — the input `ForgeCompetitiveScorePolicy`'s repetition
  /// penalty is driven from. Session-scoped rather than persisted: a fresh
  /// app session starting the repetition count over is an accepted
  /// simplification of this local/mock phase.
  final Map<String, int> _familyCompletionCounts = {};

  Future<void> get ready => _readyCompleter.future;

  @override
  CompetitionState build() {
    final authStatus = ref.watch(
      authStateNotifierProvider.select((s) => s.status),
    );
    if (authStatus == AuthStatus.unauthenticated) {
      ref.read(competitionRepositoryProvider).clearForUser(_userId);
      _reactedMissionInstanceIds.clear();
      _familyCompletionCounts.clear();
      return const CompetitionLoading();
    }

    Future.microtask(() async {
      await _refresh();
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    });
    return const CompetitionLoading();
  }

  String get _userId => ref.read(currentCompetitionUserIdProvider);

  Future<void> _refresh() async {
    try {
      final userId = _userId;
      final displayName =
          ref.read(authStateNotifierProvider).session?.user.displayName ??
          'You';
      final now = ref.read(competitionClockProvider)();

      final current = await ref.read(getCurrentCompetitionStateUseCaseProvider)(
        userId,
        now: now,
        displayName: displayName,
      );
      final hallOfFame = await ref.read(getHallOfFameUseCaseProvider)();
      final seasonProgress = await ref.read(getSeasonProgressUseCaseProvider)(
        userId,
        now: now,
      );

      state = CompetitionReady(
        current: current,
        hallOfFame: hallOfFame,
        seasonProgress: seasonProgress,
      );
    } catch (_) {
      state = const CompetitionError(
        "Couldn't load your competition standing right now.",
      );
    }
  }

  /// Idempotent per [MissionInstance.instanceId] — see
  /// `ProgressionController.reactToMissionCompletion`'s identical
  /// reasoning. [xpEvaluation] is read only for its display-only
  /// [XpRewardEvaluation.finalXpPreview]; competition never derives its
  /// own score from XP (see module trust-boundary notes).
  Future<void> reactToMissionCompletion({
    required MissionInstance instance,
    required XpRewardEvaluation xpEvaluation,
    required String userId,
  }) async {
    if (!_reactedMissionInstanceIds.add(instance.instanceId)) return;

    final repeatedMissionCount =
        _familyCompletionCounts[instance.definitionId] ?? 0;
    _familyCompletionCounts[instance.definitionId] = repeatedMissionCount + 1;

    final completedAt = ref.read(competitionClockProvider)();
    final summary = CompetitiveCompletionSummary(
      missionInstanceId: instance.instanceId,
      userId: userId,
      completedAt: completedAt,
      category: instance.category,
      difficulty: instance.resolvedDifficulty,
      provisionalXp: xpEvaluation.finalXpPreview,
      recoveryMission: instance.recoveryMission,
      repeatedMissionCount: repeatedMissionCount,
      completionQuality: CompletionQuality.standard,
      validationState: CompletionValidationState.valid,
      eventIntegrityState: CompetitionIntegrityState.clean,
      rewardAuthorityState: RewardAuthorityState.localPreviewOnly,
    );

    final repository = ref.read(competitionRepositoryProvider);
    final season = await repository.getCurrentSeason();
    final week =
        CompetitionCalendar.currentWeekFor(season, completedAt) ??
        CompetitionCalendar.weeksFor(season, completedAt).last;

    await ref.read(calculateCompetitiveMissionScoreUseCaseProvider)(
      summary,
      weekStartsAt: week.startsAt,
    );

    await _refresh();
  }

  /// The one place a real `submit-mission` server response is allowed to
  /// affect competition state (spec section 11 — Phase 10D). Never
  /// touches [CompetitionReady.current] (which stays entirely local-
  /// provisional, freshly re-derived by [_refresh]) — only appends to
  /// the separate, explicitly-confirmed [CompetitionReady
  /// .confirmedContributions] list. Idempotent per mission instance via
  /// [CompetitionReconciliation.appendConfirmed].
  void applyServerConfirmedScore({
    required String missionInstanceId,
    required double confirmedScoreDelta,
    required String integrityStatus,
    required DateTime confirmedAt,
  }) {
    final current = state;
    if (current is! CompetitionReady) return;

    final updated = CompetitionReconciliation.appendConfirmed(
      current.confirmedContributions,
      ConfirmedCompetitionContribution(
        missionInstanceId: missionInstanceId,
        confirmedScoreDelta: confirmedScoreDelta,
        integrityStatus: integrityStatus,
        confirmedAt: confirmedAt,
      ),
    );

    state = CompetitionReady(
      current: current.current,
      hallOfFame: current.hallOfFame,
      seasonProgress: current.seasonProgress,
      confirmedContributions: updated,
      confirmedWeeklyStanding: current.confirmedWeeklyStanding,
      confirmedWeeklyStandingFreshness:
          current.confirmedWeeklyStandingFreshness,
    );
  }

  /// Fetches this user's own row from the confirmed weekly leaderboard
  /// (spec section 8/9) and folds it into state — a cache-fallback
  /// failure still updates [CompetitionReady.confirmedWeeklyStanding]
  /// (with [CompetitionAuthorityStatus.confirmedStale]) rather than
  /// leaving the UI with nothing to show. Never overwrites
  /// [CompetitionReady.current] itself, which stays entirely local-
  /// provisional (see that field's own doc comment).
  Future<void> refreshConfirmedWeeklyStanding() async {
    final current = state;
    if (current is! CompetitionReady) return;

    final userId = _userId;
    final result = await ref
        .read(cachedLeaderboardFetcherProvider)
        .fetchWeekly(
          seasonId: current.current.season.id,
          weekNumber: current.current.week.weekNumber,
          leagueId: current.current.league.id,
        );

    PublicWeeklyLeaderboardEntry? own;
    for (final entry in result.entries) {
      if (entry.userId == userId) {
        own = entry;
        break;
      }
    }

    state = CompetitionReady(
      current: current.current,
      hallOfFame: current.hallOfFame,
      seasonProgress: current.seasonProgress,
      confirmedContributions: current.confirmedContributions,
      confirmedWeeklyStanding: own ?? current.confirmedWeeklyStanding,
      confirmedWeeklyStandingFreshness: result.freshness,
    );
  }
}

final competitionControllerProvider =
    NotifierProvider<CompetitionController, CompetitionState>(
      CompetitionController.new,
    );
