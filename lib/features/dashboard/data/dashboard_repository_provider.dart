import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/missions/data/mission_preview_adapter.dart';
import '../../../features/missions/presentation/providers/resolved_mission_instance_controller.dart';
import '../../auth/presentation/auth_state_notifier.dart';
import '../domain/dashboard_repository.dart';
import 'mock/mock_dashboard_repository.dart';

/// Which canned scenario [MockDashboardRepository] serves — overridden in
/// tests to reach every dashboard state deterministically. There is no
/// live repository yet (out of scope for this phase), so this is the only
/// implementation regardless of `AppConfig.environment`.
final dashboardMockScenarioProvider = Provider<DashboardMockScenario>((ref) {
  return DashboardMockScenario.normalActive;
});

/// Reactive on purpose: watching `resolvedMissionInstanceProvider` here
/// (rather than reading it once) is what lets `DashboardNotifier`
/// automatically re-fetch once mission resolution lands after Dashboard's
/// own first load already returned — see its doc comment. In live mode
/// this is the server-confirmed mission once assignment resolves (Roadmap
/// Item 13C) — never a separately-generated local instance.
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final session = ref.watch(authStateNotifierProvider).session;
  final resolved = ref.watch(resolvedMissionInstanceProvider);
  return MockDashboardRepository(
    scenario: ref.watch(dashboardMockScenarioProvider),
    displayName: session?.user.displayName ?? 'Warrior',
    missionOverride: resolved == null
        ? null
        : missionPreviewFromInstance(
            resolved.instance,
            transmissionAvailable: true,
          ),
  );
});
