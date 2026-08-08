import '../dashboard_repository.dart';

class GetDashboardOverviewUseCase {
  const GetDashboardOverviewUseCase(this._repository);

  final DashboardRepository _repository;

  Future<DashboardOverviewResult?> call() => _repository.getOverview();
}
