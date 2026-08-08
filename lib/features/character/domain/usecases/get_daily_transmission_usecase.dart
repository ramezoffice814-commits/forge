import '../../../dashboard/domain/entities/dashboard_overview.dart';
import '../entities/transmission_script.dart';
import '../repositories/transmission_repository.dart';

/// Thin pass-through over [TransmissionRepository] — kept as its own class
/// (matching `GetDashboardOverviewUseCase`'s pattern) so the controller
/// depends on a use case, not a repository, if a second data source is ever
/// composed in front of it.
class GetDailyTransmissionUseCase {
  const GetDailyTransmissionUseCase(this._repository);

  final TransmissionRepository _repository;

  Future<TransmissionScript> call(DashboardOverview dashboard) {
    return _repository.getDailyTransmission(dashboard);
  }
}
