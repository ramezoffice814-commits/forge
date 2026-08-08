import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../missions/presentation/providers/mission_selection_controller.dart';
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
      // Wait for the mission-selection engine's first result (success or
      // error) before fetching, so Dashboard's one and only load already
      // has mission data — no reactive "loading flickers again a moment
      // later" once selection resolves.
      await ref.read(missionSelectionControllerProvider.notifier).ready;
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
