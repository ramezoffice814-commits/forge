import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_state.dart';
import '../../../auth/presentation/auth_state_notifier.dart';
import '../../../missions/domain/entities/mission_instance.dart';
import '../../../progression/domain/entities/xp_reward_evaluation.dart';
import '../../domain/entities/competitive_completion_summary.dart';
import '../../domain/enums/completion_quality.dart';
import '../../domain/enums/completion_validation_state.dart';
import '../../domain/enums/competition_integrity_state.dart';
import '../../domain/enums/reward_authority_state.dart';
import '../../domain/policies/competition_calendar.dart';
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
}

final competitionControllerProvider =
    NotifierProvider<CompetitionController, CompetitionState>(
      CompetitionController.new,
    );
