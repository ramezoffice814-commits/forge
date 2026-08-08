import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/progression/data/catalog/level_catalog.dart';
import 'package:forge/features/progression/domain/entities/level_definition.dart';
import 'package:forge/features/progression/domain/policies/level_policy.dart';

void main() {
  final catalog = LevelCatalog.build();

  test('level 1 requires 0 XP', () {
    expect(LevelPolicy.levelFor(0, catalog).levelNumber, 1);
  });

  test('exactly at a level\'s required XP reaches that level (boundary)', () {
    final level3 = catalog.firstWhere((l) => l.levelNumber == 3);
    expect(LevelPolicy.levelFor(level3.requiredXp, catalog).levelNumber, 3);
  });

  test('one XP short of a level stays at the previous level (boundary)', () {
    final level3 = catalog.firstWhere((l) => l.levelNumber == 3);
    expect(LevelPolicy.levelFor(level3.requiredXp - 1, catalog).levelNumber, 2);
  });

  test('XP never decreases the level relative to a lower XP total', () {
    final low = LevelPolicy.levelFor(10, catalog).levelNumber;
    final high = LevelPolicy.levelFor(10000, catalog).levelNumber;
    expect(high, greaterThanOrEqualTo(low));
  });

  test('nextLevel is null at the top of the catalog', () {
    final top = catalog.last;
    expect(LevelPolicy.nextLevel(top, catalog), isNull);
  });

  test('progressToNextLevel is 1.0 at the top level', () {
    final top = catalog.last;
    expect(LevelPolicy.progressToNextLevel(top.requiredXp, catalog), 1.0);
  });

  test('progressToNextLevel is 0.0 exactly at a level\'s threshold', () {
    final level2 = catalog.firstWhere((l) => l.levelNumber == 2);
    expect(LevelPolicy.progressToNextLevel(level2.requiredXp, catalog), 0.0);
  });

  test('xpToNextLevel is 0 at the top level', () {
    final top = catalog.last;
    expect(LevelPolicy.xpToNextLevel(top.requiredXp, catalog), 0);
  });

  test('the catalog supports future expansion without code changes '
      '(adding a level is purely catalog data)', () {
    final extraLevel = LevelDefinition(
      levelNumber: catalog.last.levelNumber + 1,
      requiredXp: catalog.last.requiredXp + 1000,
      title: 'Beyond the Catalog',
      description: 'A level added purely as data.',
    );
    final extended = [...catalog, extraLevel];
    final result = LevelPolicy.levelFor(extraLevel.requiredXp, extended);
    expect(result.levelNumber, extraLevel.levelNumber);
  });
}
