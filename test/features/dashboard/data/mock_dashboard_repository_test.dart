import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/dashboard/data/mock/mock_dashboard_repository.dart';
import 'package:forge/features/dashboard/domain/dashboard_failure.dart';

void main() {
  group('MockDashboardRepository', () {
    test(
      'normalActive returns a populated overview with an active mission',
      () async {
        final repo = MockDashboardRepository(
          scenario: DashboardMockScenario.normalActive,
        );
        final result = await repo.getOverview();

        expect(result, isNotNull);
        expect(result!.isOfflineCache, isFalse);
        expect(result.overview.currentDay, 26);
        expect(result.overview.recoveryModeActive, isFalse);
      },
    );

    test(
      'newUser returns a zeroed-out overview ("first authenticated session")',
      () async {
        final repo = MockDashboardRepository(
          scenario: DashboardMockScenario.newUser,
        );
        final result = await repo.getOverview();

        expect(result!.overview.currentDay, 0);
        expect(result.overview.currentStreak, 0);
        expect(result.overview.lifetimeXp, 0);
        expect(result.overview.levelProgress, 0);
      },
    );

    test(
      'recoveryMode marks recoveryModeActive and gives an easier mission',
      () async {
        final repo = MockDashboardRepository(
          scenario: DashboardMockScenario.recoveryMode,
        );
        final result = await repo.getOverview();

        expect(result!.overview.recoveryModeActive, isTrue);
        expect(result.overview.todayMissionPreview.difficulty.name, 'easy');
      },
    );

    test('completedMission marks the mission completed', () async {
      final repo = MockDashboardRepository(
        scenario: DashboardMockScenario.completedMission,
      );
      final result = await repo.getOverview();

      expect(result!.overview.todayMissionPreview.status.name, 'completed');
    });

    test('offlineCached flags the result as an offline cache', () async {
      final repo = MockDashboardRepository(
        scenario: DashboardMockScenario.offlineCached,
      );
      final result = await repo.getOverview();

      expect(result!.isOfflineCache, isTrue);
      expect(result.overview.currentDay, greaterThan(0));
    });

    test('empty returns null', () async {
      final repo = MockDashboardRepository(
        scenario: DashboardMockScenario.empty,
      );
      expect(await repo.getOverview(), isNull);
    });

    test('offlineNoCache throws DashboardOfflineFailure', () async {
      final repo = MockDashboardRepository(
        scenario: DashboardMockScenario.offlineNoCache,
      );
      await expectLater(
        repo.getOverview(),
        throwsA(
          isA<DashboardException>().having(
            (e) => e.failure,
            'failure',
            isA<DashboardOfflineFailure>(),
          ),
        ),
      );
    });

    test('networkError throws DashboardNetworkFailure', () async {
      final repo = MockDashboardRepository(
        scenario: DashboardMockScenario.networkError,
      );
      await expectLater(
        repo.getOverview(),
        throwsA(
          isA<DashboardException>().having(
            (e) => e.failure,
            'failure',
            isA<DashboardNetworkFailure>(),
          ),
        ),
      );
    });

    test('repositoryError throws DashboardUnknownFailure', () async {
      final repo = MockDashboardRepository(
        scenario: DashboardMockScenario.repositoryError,
      );
      await expectLater(
        repo.getOverview(),
        throwsA(
          isA<DashboardException>().having(
            (e) => e.failure,
            'failure',
            isA<DashboardUnknownFailure>(),
          ),
        ),
      );
    });

    test('scenarios are deterministic across repeated calls', () async {
      final repo = MockDashboardRepository(
        scenario: DashboardMockScenario.normalActive,
      );
      final first = await repo.getOverview();
      final second = await repo.getOverview();

      expect(first!.overview.currentDay, second!.overview.currentDay);
      expect(first.overview.lifetimeXp, second.overview.lifetimeXp);
      expect(
        first.overview.todayMissionPreview.title,
        second.overview.todayMissionPreview.title,
      );
    });

    test(
      'displayName flows through from the constructor (real signed-in user)',
      () async {
        final repo = MockDashboardRepository(
          scenario: DashboardMockScenario.normalActive,
          displayName: 'Jordan K.',
        );
        final result = await repo.getOverview();
        expect(result!.overview.displayName, 'Jordan K.');
      },
    );
  });
}
