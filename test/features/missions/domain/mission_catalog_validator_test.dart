import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/entities/mission_catalog_validator.dart';
import 'package:forge/features/missions/domain/entities/mission_definition.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/missions/domain/enums/proof_policy.dart';
import 'package:forge/features/missions/domain/enums/safety_classification.dart';

MissionDefinition _valid({
  int minimumMinutes = 5,
  int estimatedMinutes = 5,
  int maximumMinutes = 10,
  MissionDifficultyLevel minimumDifficulty = MissionDifficultyLevel.easy,
  MissionDifficultyLevel baseDifficulty = MissionDifficultyLevel.easy,
  MissionDifficultyLevel maximumDifficulty = MissionDifficultyLevel.easy,
  List<String> completionConditions = const ['Do the thing'],
  bool active = true,
}) {
  return MissionDefinition(
    id: 'm1',
    version: 1,
    title: 'Test Mission',
    description: 'A test mission.',
    category: MissionCategory.fitness,
    baseDifficulty: baseDifficulty,
    minimumDifficulty: minimumDifficulty,
    maximumDifficulty: maximumDifficulty,
    estimatedMinutes: estimatedMinutes,
    minimumMinutes: minimumMinutes,
    maximumMinutes: maximumMinutes,
    baseXpHint: 10,
    completionConditions: completionConditions,
    proofPolicy: ProofPolicy.none,
    safetyClassification: SafetyClassification.standard,
    recoveryEligible: true,
    repeatCooldownDays: 0,
    maximumOccurrencesPerWeek: 7,
    active: active,
  );
}

void main() {
  test('a well-formed entry validates', () {
    expect(MissionCatalogValidator.validate(_valid()), isEmpty);
    expect(MissionCatalogValidator.isValid(_valid()), isTrue);
  });

  test('invalid duration bounds are rejected', () {
    final maxBelowMin = _valid(
      minimumMinutes: 10,
      maximumMinutes: 5,
      estimatedMinutes: 10,
    );
    expect(MissionCatalogValidator.isValid(maxBelowMin), isFalse);

    final estimatedOutOfRange = _valid(
      minimumMinutes: 5,
      maximumMinutes: 10,
      estimatedMinutes: 20,
    );
    expect(MissionCatalogValidator.isValid(estimatedOutOfRange), isFalse);

    final exceedsAbsoluteCap = _valid(
      minimumMinutes: 5,
      estimatedMinutes: 95,
      maximumMinutes: 95,
    );
    expect(MissionCatalogValidator.isValid(exceedsAbsoluteCap), isFalse);
  });

  test('invalid difficulty range is rejected', () {
    final inverted = _valid(
      minimumDifficulty: MissionDifficultyLevel.challenging,
      maximumDifficulty: MissionDifficultyLevel.easy,
      baseDifficulty: MissionDifficultyLevel.easy,
    );
    expect(MissionCatalogValidator.isValid(inverted), isFalse);

    final baseOutOfRange = _valid(
      minimumDifficulty: MissionDifficultyLevel.easy,
      maximumDifficulty: MissionDifficultyLevel.easy,
      baseDifficulty: MissionDifficultyLevel.advanced,
    );
    expect(MissionCatalogValidator.isValid(baseOutOfRange), isFalse);
  });

  test('malformed completion conditions are rejected', () {
    expect(
      MissionCatalogValidator.isValid(_valid(completionConditions: const [])),
      isFalse,
    );
    expect(
      MissionCatalogValidator.isValid(_valid(completionConditions: const [''])),
      isFalse,
    );
  });

  test('inactive entries validate structurally but are excluded elsewhere', () {
    // `active` is not itself a structural-validity concern — it's checked
    // by the safety policy/engine, not the validator. See
    // mission_safety_policy_test.dart for "catalogEntryInactive".
    expect(MissionCatalogValidator.isValid(_valid(active: false)), isTrue);
  });
}
