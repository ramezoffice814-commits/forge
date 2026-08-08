import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/features/dashboard/data/dashboard_repository_provider.dart';
import 'package:forge/features/dashboard/data/mock/mock_dashboard_repository.dart';
import 'package:forge/features/dashboard/presentation/dashboard_notifier.dart';
import 'package:forge/features/dashboard/presentation/dashboard_state.dart';

import '../../../support/fake_secure_key_value_store.dart';

void main() {
  ProviderContainer makeContainer(DashboardMockScenario scenario) {
    final container = ProviderContainer(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
        dashboardMockScenarioProvider.overrideWithValue(scenario),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Reading the provider triggers `build()` (lazy) which kicks off the
  /// mock's simulated fetch — must happen *before* waiting for it to
  /// resolve, not after. Polls rather than sleeping a fixed duration:
  /// Dashboard now reactively reloads a second time once the mission-
  /// selection engine resolves (see `dashboard_repository_provider.dart`),
  /// so a single fixed wait can no longer safely bound "fully settled".
  Future<ProviderContainer> makeAndLoad(DashboardMockScenario scenario) async {
    final container = makeContainer(scenario);
    container.read(dashboardNotifierProvider); // triggers build()/_load()

    final stopwatch = Stopwatch()..start();
    while (container.read(dashboardNotifierProvider) is DashboardLoading) {
      if (stopwatch.elapsed > const Duration(seconds: 3)) {
        throw StateError('Dashboard did not finish loading in time');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    // One more short settle: a populated state can still flip to a second
    // DashboardLoading briefly when the mission engine resolves just after
    // the first load completes.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    while (container.read(dashboardNotifierProvider) is DashboardLoading) {
      if (stopwatch.elapsed > const Duration(seconds: 3)) {
        throw StateError('Dashboard did not finish loading in time');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return container;
  }

  test('starts in DashboardLoading', () {
    final container = makeContainer(DashboardMockScenario.normalActive);
    expect(container.read(dashboardNotifierProvider), isA<DashboardLoading>());
  });

  test(
    'normalActive resolves to DashboardPopulated (not offline cache)',
    () async {
      final container = await makeAndLoad(DashboardMockScenario.normalActive);

      final state = container.read(dashboardNotifierProvider);
      expect(state, isA<DashboardPopulated>());
      final populated = state as DashboardPopulated;
      expect(populated.isOfflineCache, isFalse);
      expect(populated.overview.levelProgress, inInclusiveRange(0.0, 1.0));
    },
  );

  test(
    'recoveryMode resolves to a populated state with recoveryModeActive true',
    () async {
      final container = await makeAndLoad(DashboardMockScenario.recoveryMode);

      final state =
          container.read(dashboardNotifierProvider) as DashboardPopulated;
      expect(state.overview.recoveryModeActive, isTrue);
    },
  );

  test(
    'offlineCached resolves to DashboardPopulated with isOfflineCache true',
    () async {
      final container = await makeAndLoad(DashboardMockScenario.offlineCached);

      final state =
          container.read(dashboardNotifierProvider) as DashboardPopulated;
      expect(state.isOfflineCache, isTrue);
    },
  );

  test('empty resolves to DashboardEmpty', () async {
    final container = await makeAndLoad(DashboardMockScenario.empty);
    expect(container.read(dashboardNotifierProvider), isA<DashboardEmpty>());
  });

  test('offlineNoCache resolves to DashboardOfflineNoCache', () async {
    final container = await makeAndLoad(DashboardMockScenario.offlineNoCache);
    expect(
      container.read(dashboardNotifierProvider),
      isA<DashboardOfflineNoCache>(),
    );
  });

  test('networkError resolves to a recoverable DashboardErrorState', () async {
    final container = await makeAndLoad(DashboardMockScenario.networkError);

    final state =
        container.read(dashboardNotifierProvider) as DashboardErrorState;
    expect(state.recoverable, isTrue);
  });

  test(
    'repositoryError resolves to an unrecoverable DashboardErrorState',
    () async {
      final container = await makeAndLoad(
        DashboardMockScenario.repositoryError,
      );

      final state =
          container.read(dashboardNotifierProvider) as DashboardErrorState;
      expect(state.recoverable, isFalse);
    },
  );

  test('retry() re-fetches and can transition out of an error state', () async {
    final container = await makeAndLoad(DashboardMockScenario.repositoryError);
    expect(
      container.read(dashboardNotifierProvider),
      isA<DashboardErrorState>(),
    );

    // Simulate the underlying condition clearing, then retry.
    container.updateOverrides([
      secureKeyValueStoreProvider.overrideWithValue(FakeSecureKeyValueStore()),
      dashboardMockScenarioProvider.overrideWithValue(
        DashboardMockScenario.normalActive,
      ),
    ]);
    await container.read(dashboardNotifierProvider.notifier).retry();

    expect(
      container.read(dashboardNotifierProvider),
      isA<DashboardPopulated>(),
    );
  });
}
