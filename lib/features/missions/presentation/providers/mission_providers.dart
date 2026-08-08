import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_mission_context.dart';
import '../../data/repositories/mock_mission_catalog_repository.dart';
import '../../domain/repositories/mission_catalog_repository.dart';

/// Which canned (profile, history, date) triple the mission engine runs
/// against — overridden in tests/goldens to reach every scenario
/// deterministically. There is no live profile/history source yet (out of
/// scope for this phase).
final missionMockScenarioProvider = Provider<MockMissionContextScenario>((ref) {
  return MockMissionContextScenario.normalActive;
});

/// Models the "engine error" dashboard scenario: the catalog *fetch*
/// failing, not the engine itself misbehaving (the engine is pure and
/// deterministic — it doesn't have failure modes of its own for a
/// supported profile).
final missionCatalogUnavailableProvider = Provider<bool>((ref) => false);

final missionCatalogRepositoryProvider = Provider<MissionCatalogRepository>((
  ref,
) {
  return MockMissionCatalogRepository(
    simulateUnavailable: ref.watch(missionCatalogUnavailableProvider),
  );
});

/// The local device/session identity events are attributed to. There is no
/// live auth-derived id wired in yet (out of scope for this phase — see the
/// mission engine's own scoping notes), so this reads the same canned
/// profile the selection engine already runs against.
final currentMissionUserIdProvider = Provider<String>((ref) {
  final scenario = ref.watch(missionMockScenarioProvider);
  return MockMissionContexts.forScenario(scenario).profile.userId;
});
