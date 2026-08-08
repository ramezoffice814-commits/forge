import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/data/catalog/mock_mission_catalog.dart';
import 'package:forge/features/missions/domain/entities/mission_catalog_validator.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';

void main() {
  final entries = MockMissionCatalog.entries;

  test('the catalog has at least 30 curated missions', () {
    expect(entries.length, greaterThanOrEqualTo(30));
  });

  test('every catalog entry is structurally valid', () {
    for (final mission in entries) {
      expect(
        MissionCatalogValidator.validate(mission),
        isEmpty,
        reason: '${mission.id}: ${MissionCatalogValidator.validate(mission)}',
      );
    }
  });

  test('every mission id is unique', () {
    final ids = entries.map((m) => m.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every category is represented', () {
    final categories = entries.map((m) => m.category).toSet();
    expect(categories, MissionCategory.values.toSet());
  });

  test('at least 4 missions are tagged as universal fallbacks', () {
    final fallbacks = entries.where(
      (m) => m.tags.contains('universalFallback'),
    );
    expect(fallbacks.length, greaterThanOrEqualTo(4));
    // Fallbacks must be trivially cheap/safe: tiny, easy, active.
    for (final fallback in fallbacks) {
      expect(fallback.active, isTrue);
      expect(fallback.minimumMinutes, lessThanOrEqualTo(5));
    }
  });

  test('no mission exceeds the absolute duration cap', () {
    for (final mission in entries) {
      expect(
        mission.maximumMinutes,
        lessThanOrEqualTo(kMissionAbsoluteMaxMinutes),
      );
    }
  });

  test('the fitness push-up progression track is ordered correctly', () {
    final pushups =
        entries.where((m) => m.progressionGroup == 'pushups_track').toList()
          ..sort((a, b) => a.progressionStep!.compareTo(b.progressionStep!));
    expect(pushups.length, 3);
    expect(pushups.map((m) => m.progressionStep), [1, 2, 3]);
  });

  test('an accessibility alternative always points to another real entry', () {
    final byId = {for (final m in entries) m.id: m};
    for (final mission in entries) {
      final altId = mission.accessibilityAlternativeId;
      if (altId == null) continue;
      expect(byId.containsKey(altId), isTrue, reason: 'missing alt $altId');
    }
  });
}
