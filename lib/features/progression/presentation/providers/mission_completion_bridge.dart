import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../missions/domain/aggregates/mission_aggregate.dart';
import '../../../missions/domain/aggregates/mission_lifecycle_state.dart'
    as lifecycle;
import '../../../missions/presentation/providers/mission_lifecycle_controller.dart';
import '../../../missions/presentation/providers/mission_lifecycle_state.dart';
import '../../../missions/presentation/providers/resolved_mission_instance_controller.dart';
import '../../domain/entities/completed_mission_summary.dart';
import 'progression_controller.dart';
import 'progression_providers.dart';

/// The one narrow bridge from the missions module into progression —
/// nothing here computes XP or touches progression state directly, it only
/// ever turns a validated `MissionAggregate` into a `CompletedMissionSummary`
/// and hands it to `ProgressionController.reactToMissionCompletion`, which
/// is itself idempotent per mission instance. Kept as its own provider
/// (watched once from a long-lived screen — see `DashboardPage`) rather
/// than living inside any single page's state, so it keeps working
/// regardless of which screen the user is actually looking at when a
/// mission completes.
final missionCompletionBridgeProvider = Provider<void>((ref) {
  // resolvedMissionInstanceProvider, not missionInstanceProvider (Roadmap
  // Item 13C): missionLifecycleControllerProvider below is keyed by the
  // server-confirmed id in live mode — watching the local instance here
  // would listen to a different, never-driven family instance and this
  // bridge would never see a real completion.
  final instance = ref.watch(resolvedMissionInstanceProvider)?.instance;
  if (instance == null) return;

  void reactIfCompleted(MissionAggregate aggregate) {
    if (aggregate.lifecycleState != lifecycle.MissionLifecycleState.completed) {
      return;
    }
    final userId = ref.read(currentProgressionUserIdProvider);
    final summary = CompletedMissionSummary(
      missionInstanceId: instance.instanceId,
      definitionId: instance.definitionId,
      userId: userId,
      category: instance.category,
      difficulty: instance.resolvedDifficulty,
      baseXpHint: instance.xpHint,
      resolvedDurationMinutes: instance.resolvedDuration,
      recoveryMission: instance.recoveryMission,
      completedAt: aggregate.completedAt ?? DateTime.now(),
    );
    ref
        .read(progressionControllerProvider.notifier)
        .reactToMissionCompletion(summary);
  }

  final initialState = ref.read(
    missionLifecycleControllerProvider(instance.instanceId),
  );
  if (initialState is MissionLifecycleReady) {
    reactIfCompleted(initialState.aggregate);
  }

  ref.listen<MissionLifecycleControllerState>(
    missionLifecycleControllerProvider(instance.instanceId),
    (previous, next) {
      if (next is MissionLifecycleReady) reactIfCompleted(next.aggregate);
    },
  );
});
