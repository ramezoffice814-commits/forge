import '../entities/behavioral_history.dart';
import '../entities/mission_selection_request.dart';
import '../entities/mission_selection_result.dart';
import '../entities/user_discipline_profile.dart';
import '../enums/mission_category.dart';
import '../mission_selection_engine.dart';
import '../repositories/mission_catalog_repository.dart';

/// Thin orchestration: fetch the catalog, hand everything to the pure
/// engine. Kept separate from `MissionSelectionEngine` itself so the engine
/// stays a pure function while this use case is the one place that talks
/// to a repository.
class SelectDailyMissionUseCase {
  const SelectDailyMissionUseCase(this._catalogRepository);

  final MissionCatalogRepository _catalogRepository;

  Future<MissionSelectionResult> call({
    required UserDisciplineProfile profile,
    required BehavioralHistory history,
    required DateTime currentDateTime,
    MissionCategory? requestedCategory,
    int? requestedDuration,
    bool? recoveryOverride,
    Set<String> excludedMissionIds = const {},
    String contextSource = 'dashboard',
  }) async {
    final catalog = await _catalogRepository.getCatalog();
    return MissionSelectionEngine.select(
      MissionSelectionRequest(
        profile: profile,
        history: history,
        currentDateTime: currentDateTime,
        catalog: catalog,
        requestedCategory: requestedCategory,
        requestedDuration: requestedDuration,
        recoveryOverride: recoveryOverride,
        excludedMissionIds: excludedMissionIds,
        contextSource: contextSource,
      ),
    );
  }
}
