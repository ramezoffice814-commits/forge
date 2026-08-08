import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_mission_context.dart';
import '../../domain/entities/mission_instance.dart';
import 'mission_providers.dart';
import 'mission_selection_controller.dart';
import 'mission_selection_state.dart';

/// Derives the one authoritative [MissionInstance] for the current local
/// session from [missionSelectionControllerProvider] — `null` while
/// loading or on error, so callers (Dashboard, Transmission) share exactly
/// this and never independently re-decide "today's mission". The instance
/// id is deterministic (mission id + calendar date), not random, so it's
/// reproducible for the same inputs like everything else in this engine.
final missionInstanceProvider = Provider<MissionInstance?>((ref) {
  final state = ref.watch(missionSelectionControllerProvider);
  if (state is! MissionSelectionReady) return null;

  final scenario = ref.watch(missionMockScenarioProvider);
  final now = MockMissionContexts.forScenario(scenario).now;
  final result = state.result;
  final dateKey =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  return MissionInstance.fromSelectionResult(
    result,
    instanceId: '${result.selectedMission.id}-$dateKey',
    assignedDate: now,
  );
});
