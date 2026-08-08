import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/missions/data/mission_preview_adapter.dart';
import '../../../features/missions/presentation/providers/mission_instance_provider.dart';
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

/// Reactive on purpose: watching `missionInstanceProvider` here (rather
/// than reading it once) is what lets `DashboardNotifier` automatically
/// re-fetch once the mission-selection engine resolves after Dashboard's
/// own first load already returned — see its doc comment.
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final session = ref.watch(authStateNotifierProvider).session;
  final missionInstance = ref.watch(missionInstanceProvider);
  return MockDashboardRepository(
    scenario: ref.watch(dashboardMockScenarioProvider),
    displayName: session?.user.displayName ?? 'Warrior',
    missionOverride: missionInstance == null
        ? null
        : missionPreviewFromInstance(
            missionInstance,
            transmissionAvailable: true,
          ),
  );
});
