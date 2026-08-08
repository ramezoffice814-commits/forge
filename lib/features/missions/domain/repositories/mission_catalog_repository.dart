import '../entities/mission_definition.dart';

class MissionCatalogException implements Exception {
  const MissionCatalogException(this.message);

  final String message;

  @override
  String toString() => 'MissionCatalogException: $message';
}

/// Supplies the curated catalog. Only a mock/in-memory implementation
/// exists in this phase — a server-synced catalog is a later roadmap item.
/// Designed so a server-backed implementation can later run the exact same
/// [MissionSelectionEngine] against a fetched catalog with zero engine
/// changes.
abstract class MissionCatalogRepository {
  Future<List<MissionDefinition>> getCatalog();
}
