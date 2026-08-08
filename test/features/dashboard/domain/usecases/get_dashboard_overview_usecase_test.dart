import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/dashboard/data/mock/mock_dashboard_repository.dart';
import 'package:forge/features/dashboard/domain/usecases/get_dashboard_overview_usecase.dart';

void main() {
  test('returns the repository\'s overview unchanged', () async {
    final useCase = GetDashboardOverviewUseCase(
      MockDashboardRepository(scenario: DashboardMockScenario.normalActive),
    );
    final result = await useCase.call();
    expect(result!.overview.currentDay, 26);
  });

  test('returns null when the repository has no data', () async {
    final useCase = GetDashboardOverviewUseCase(
      MockDashboardRepository(scenario: DashboardMockScenario.empty),
    );
    expect(await useCase.call(), isNull);
  });
}
