import '../../domain/entities/mission_definition.dart';
import '../../domain/repositories/mission_catalog_repository.dart';
import '../catalog/mock_mission_catalog.dart';

/// Serves the curated mock catalog. [simulateUnavailable] models the
/// "engine error" dashboard scenario (section 20) — the *wiring*, not the
/// engine itself, failing (e.g. a catalog fetch that hasn't loaded yet).
class MockMissionCatalogRepository implements MissionCatalogRepository {
  const MockMissionCatalogRepository({this.simulateUnavailable = false});

  final bool simulateUnavailable;

  @override
  Future<List<MissionDefinition>> getCatalog() async {
    // No simulated network latency: this is an in-memory const catalog, and
    // Dashboard reactively re-fetches the instant selection resolves (see
    // `dashboardRepositoryProvider`) — an artificial delay here would only
    // widen that reactive window for no benefit.
    if (simulateUnavailable) {
      throw const MissionCatalogException('Mission catalog is unavailable.');
    }
    // Catalog data is immutable after loading — callers get the same
    // const list reference every time, never a mutable copy.
    return MockMissionCatalog.entries;
  }
}
