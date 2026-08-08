import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../missions/presentation/providers/mission_instance_provider.dart';
import '../../../progression/presentation/providers/progression_controller.dart';
import '../../../progression/presentation/providers/progression_state.dart';
import 'competition_controller.dart';
import 'competition_providers.dart';

/// The one narrow bridge from progression into competition — deliberately
/// downstream of progression (never of the raw mission lifecycle
/// directly), because the only thing competition needs from a completion
/// that it can't derive itself is the provisional XP preview, and
/// progression is the sole place that number is computed. Nothing here
/// computes a competitive score itself; it only ever turns an
/// already-evaluated `XpRewardEvaluation` into a `CompetitiveCompletionSummary`
/// via `CompetitionController.reactToMissionCompletion`.
///
/// Kept as its own provider (watched once from a long-lived screen — see
/// `DashboardPage`), same reasoning as `missionCompletionBridgeProvider`.
final competitionCompletionBridgeProvider = Provider<void>((ref) {
  final instance = ref.watch(missionInstanceProvider);
  if (instance == null) return;

  void reactIfMatches(ProgressionState state) {
    if (state is! ProgressionReady) return;
    final evaluation = state.lastXpEvaluation;
    if (evaluation == null) return;
    if (evaluation.missionInstanceId != instance.instanceId) return;

    final userId = ref.read(currentCompetitionUserIdProvider);
    ref
        .read(competitionControllerProvider.notifier)
        .reactToMissionCompletion(
          instance: instance,
          xpEvaluation: evaluation,
          userId: userId,
        );
  }

  reactIfMatches(ref.read(progressionControllerProvider));

  ref.listen<ProgressionState>(progressionControllerProvider, (previous, next) {
    reactIfMatches(next);
  });
});
