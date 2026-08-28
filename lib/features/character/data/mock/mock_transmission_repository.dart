import '../../../dashboard/domain/entities/dashboard_overview.dart';
import '../../domain/entities/transmission_script.dart';
import '../../domain/repositories/transmission_repository.dart';
import 'mock_transmission_scripts.dart';

/// Deterministic canned scenarios, mirroring `DashboardMockScenario`'s
/// pattern — every scenario always returns exactly the same script so
/// widget/golden tests stay stable.
enum TransmissionMockScenario {
  normalActive,
  firstDay,
  recovery,
  completedReplay,
  offline,
  repositoryError,
}

class MockTransmissionRepository implements TransmissionRepository {
  const MockTransmissionRepository({required this.scenario});

  final TransmissionMockScenario scenario;

  static const _simulatedDelay = Duration(milliseconds: 250);

  @override
  Future<TransmissionScript> getDailyTransmission(
    DashboardOverview dashboard,
  ) async {
    await Future<void>.delayed(_simulatedDelay);

    switch (scenario) {
      case TransmissionMockScenario.offline:
        throw const TransmissionOfflineException();
      case TransmissionMockScenario.repositoryError:
        throw const TransmissionException('Could not reach the Current.');
      case TransmissionMockScenario.normalActive:
        return MockTransmissionScripts.normalActive(
          dashboard.displayName,
          dashboard.todayMissionPreview,
        );
      case TransmissionMockScenario.firstDay:
        return MockTransmissionScripts.firstDay(
          dashboard.displayName,
          dashboard.todayMissionPreview,
        );
      case TransmissionMockScenario.recovery:
        return MockTransmissionScripts.recovery(
          dashboard.displayName,
          dashboard.todayMissionPreview,
        );
      case TransmissionMockScenario.completedReplay:
        return MockTransmissionScripts.completedReplay(
          dashboard.displayName,
          dashboard.todayMissionPreview,
        );
    }
  }
}
