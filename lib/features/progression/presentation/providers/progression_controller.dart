import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_state.dart';
import '../../../auth/presentation/auth_state_notifier.dart';
import '../../data/mock/mock_progression_context.dart';
import '../../domain/entities/achievement_progress.dart';
import '../../domain/entities/completed_mission_summary.dart';
import '../../domain/entities/xp_reward_evaluation.dart';
import '../../domain/usecases/calculate_level_usecase.dart';
import 'progression_providers.dart';
import 'progression_state.dart';

/// The single authoritative progression session, mirroring
/// `MissionSelectionController`'s shape: a `ready` future callers await
/// before their first read (rather than watching the async use-case chain
/// directly in `build()`, which would race a manual refresh — see that
/// controller's own doc comment for the full story), and one place
/// (`reactToMissionCompletion`) that turns a real mission completion into
/// an XP preview, a level check, an achievement sweep, and a title
/// re-evaluation, in that order.
class ProgressionController extends Notifier<ProgressionState> {
  final Completer<void> _readyCompleter = Completer<void>();
  final Set<String> _reactedMissionInstanceIds = {};

  Future<void> get ready => _readyCompleter.future;

  @override
  ProgressionState build() {
    // Signing out wipes local progression state — nothing provisional
    // should survive into the next session's device state (spec section
    // 26's acceptance criteria). Watching auth here (rather than auth
    // reaching into progression) keeps the dependency pointed the right
    // way: a leaf feature may read a foundational one, never the reverse.
    final authStatus = ref.watch(
      authStateNotifierProvider.select((s) => s.status),
    );
    if (authStatus == AuthStatus.unauthenticated) {
      ref.read(progressionRepositoryProvider).clearForUser(_userId);
      _reactedMissionInstanceIds.clear();
      // Deliberately does *not* fall through to re-seed below — signed-out
      // means no local progression data exists until a real sign-in
      // happens again (a later `build()` re-run, once `authStatus` flips
      // back to authenticated, takes the normal load-or-seed path).
      return const ProgressionLoading();
    }

    Future.microtask(() async {
      await _loadOrSeed();
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    });
    return const ProgressionLoading();
  }

  String get _userId => ref.read(currentProgressionUserIdProvider);

  Future<void> _loadOrSeed() async {
    final repository = ref.read(progressionRepositoryProvider);
    final userId = _userId;
    if (repository.completionsForUser(userId).isEmpty) {
      await MockProgressionContext.seed(repository, userId: userId);
    }
    await _refresh();
  }

  Future<void> _refresh({
    XpRewardEvaluation? lastXpEvaluation,
    LevelCalculationResult? lastLevelResult,
    List<AchievementProgress> recentlyUnlocked = const [],
  }) async {
    try {
      final aggregate = await ref.read(getProgressionUseCaseProvider)(_userId);
      state = ProgressionReady(
        aggregate: aggregate,
        lastXpEvaluation: lastXpEvaluation,
        lastLevelResult: lastLevelResult,
        recentlyUnlocked: recentlyUnlocked,
      );
    } catch (_) {
      state = const ProgressionError(
        "Couldn't load your progression right now.",
      );
    }
  }

  /// Idempotent per [CompletedMissionSummary.missionInstanceId] — however
  /// many times the mission-completion bridge fires for the same mission,
  /// XP is only ever evaluated once for it.
  Future<void> reactToMissionCompletion(CompletedMissionSummary summary) async {
    if (!_reactedMissionInstanceIds.add(summary.missionInstanceId)) return;

    final xpEvaluation = await ref.read(evaluateMissionRewardUseCaseProvider)(
      summary,
    );
    final levelResult = await ref.read(calculateLevelUseCaseProvider)(
      summary.userId,
      now: summary.completedAt,
    );
    final achievementResult = await ref.read(
      evaluateAchievementsUseCaseProvider,
    )(summary.userId, now: summary.completedAt);
    await ref.read(getTitlesUseCaseProvider)(
      summary.userId,
      now: summary.completedAt,
    );

    await _refresh(
      lastXpEvaluation: xpEvaluation,
      lastLevelResult: levelResult,
      recentlyUnlocked: achievementResult.newlyUnlocked,
    );
  }

  /// Explicit dismissal, same reasoning as `MissionLifecycleReady
  /// .lastFailure`: a celebration should never vanish before the user has
  /// actually seen it.
  void dismissCelebration() {
    final current = state;
    if (current is ProgressionReady) {
      state = ProgressionReady(aggregate: current.aggregate);
    }
  }
}

final progressionControllerProvider =
    NotifierProvider<ProgressionController, ProgressionState>(
      ProgressionController.new,
    );
