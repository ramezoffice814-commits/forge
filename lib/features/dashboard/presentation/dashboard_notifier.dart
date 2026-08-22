import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../missions/presentation/providers/resolved_mission_instance_controller.dart';
import '../data/dashboard_repository_provider.dart';
import '../domain/dashboard_failure.dart';
import '../domain/usecases/get_dashboard_overview_usecase.dart';
import 'dashboard_state.dart';

final getDashboardOverviewUseCaseProvider = Provider((ref) {
  return GetDashboardOverviewUseCase(ref.watch(dashboardRepositoryProvider));
});

class DashboardNotifier extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    _load();
    return const DashboardLoading();
  }

  Future<void> _load() async {
    try {
      // Wait for mission resolution's first result (success or error, and
      // in live mode the server assignment round trip too — Roadmap Item
      // 13C) before fetching, so Dashboard's one and only load already has
      // the *authoritative* mission data — no reactive "loading flickers
      // again a moment later" once resolution completes, and no race
      // where this read of resolvedMissionInstanceProvider lands before
      // its controller has ever resolved.
      await ref.read(resolvedMissionInstanceControllerProvider.notifier).ready;
      final result = await ref.read(getDashboardOverviewUseCaseProvider).call();
      state = result == null
          ? const DashboardEmpty()
          : DashboardPopulated(
              result.overview,
              isOfflineCache: result.isOfflineCache,
            );
    } on DashboardException catch (e) {
      state = switch (e.failure) {
        DashboardOfflineFailure() => const DashboardOfflineNoCache(),
        DashboardNetworkFailure() => DashboardErrorState(
          e.failure,
          recoverable: true,
        ),
        DashboardUnknownFailure() => DashboardErrorState(
          e.failure,
          recoverable: false,
        ),
      };
    } catch (_) {
      state = const DashboardErrorState(
        DashboardUnknownFailure(),
        recoverable: false,
      );
    }
  }

  Future<void> retry() async {
    state = const DashboardLoading();
    await _load();
  }
}

final dashboardNotifierProvider =
    NotifierProvider<DashboardNotifier, DashboardState>(DashboardNotifier.new);
