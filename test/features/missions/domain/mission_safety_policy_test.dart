import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/entities/mission_definition.dart';
import 'package:forge/features/missions/domain/entities/user_discipline_profile.dart';
import 'package:forge/features/missions/domain/enums/data_confidence.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/missions/domain/enums/proof_policy.dart';
import 'package:forge/features/missions/domain/enums/safety_classification.dart';
import 'package:forge/features/missions/domain/policies/mission_safety_policy.dart';

MissionDefinition _mission({
  MissionCategory category = MissionCategory.fitness,
  MissionDifficultyLevel baseDifficulty = MissionDifficultyLevel.easy,
  MissionDifficultyLevel minimumDifficulty = MissionDifficultyLevel.easy,
  MissionDifficultyLevel maximumDifficulty = MissionDifficultyLevel.easy,
  SafetyClassification safetyClassification = SafetyClassification.standard,
  Set<String> excludedConditions = const {},
  String? accessibilityAlternativeId,
  bool recoveryEligible = true,
  bool active = true,
}) {
  return MissionDefinition(
    id: 'm1',
    version: 1,
    title: 'Test Mission',
    description: 'desc',
    category: category,
    baseDifficulty: baseDifficulty,
    minimumDifficulty: minimumDifficulty,
    maximumDifficulty: maximumDifficulty,
    estimatedMinutes: 5,
    minimumMinutes: 3,
    maximumMinutes: 10,
    baseXpHint: 10,
    completionConditions: const ['Do it'],
    proofPolicy: ProofPolicy.none,
    safetyClassification: safetyClassification,
    excludedConditions: excludedConditions,
    accessibilityAlternativeId: accessibilityAlternativeId,
    recoveryEligible: recoveryEligible,
    repeatCooldownDays: 0,
    maximumOccurrencesPerWeek: 7,
    active: active,
  );
}

const _profile = UserDisciplineProfile(userId: 'u1');

void main() {
  test('inactive catalog entries are denied', () {
    final decision = MissionSafetyPolicy.evaluate(
      mission: _mission(active: false),
      profile: _profile,
      recoveryActive: false,
    );
    expect(decision.isDenied, isTrue);
    expect(decision.reasonCodes, contains('catalogEntryInactive'));
  });

  test('a category the user avoids is denied', () {
    final profile = _profile.copyWith(
      avoidedCategories: {MissionCategory.fitness},
    );
    final decision = MissionSafetyPolicy.evaluate(
      mission: _mission(),
      profile: profile,
      recoveryActive: false,
    );
    expect(decision.isDenied, isTrue);
    expect(decision.reasonCodes, contains('prohibitedCategory'));
  });

  test('a user-declared restriction is respected, with the alt noted when '
      'present', () {
    final profile = _profile.copyWith(healthLimitations: {'knee_sensitive'});

    final withoutAlt = MissionSafetyPolicy.evaluate(
      mission: _mission(excludedConditions: {'knee_sensitive'}),
      profile: profile,
      recoveryActive: false,
    );
    expect(withoutAlt.isDenied, isTrue);
    expect(withoutAlt.reasonCodes, contains('conflictsWithUserRestriction'));
    expect(withoutAlt.reasonCodes, contains('missingAccessibilityAlternative'));

    final withAlt = MissionSafetyPolicy.evaluate(
      mission: _mission(
        excludedConditions: {'knee_sensitive'},
        accessibilityAlternativeId: 'alt-1',
      ),
      profile: profile,
      recoveryActive: false,
    );
    expect(withAlt.isDenied, isTrue);
    expect(withAlt.reasonCodes, contains('conflictsWithUserRestriction'));
    expect(
      withAlt.reasonCodes,
      isNot(contains('missingAccessibilityAlternative')),
    );
  });

  test('a recovery-ineligible mission is denied during recovery', () {
    final decision = MissionSafetyPolicy.evaluate(
      mission: _mission(recoveryEligible: false),
      profile: _profile,
      recoveryActive: true,
    );
    expect(decision.isDenied, isTrue);
    expect(decision.reasonCodes, contains('recoveryIncompatible'));
  });

  test('a recovery-eligible mission above easy is capped down, not denied, '
      'during recovery', () {
    final decision = MissionSafetyPolicy.evaluate(
      mission: _mission(
        baseDifficulty: MissionDifficultyLevel.moderate,
        minimumDifficulty: MissionDifficultyLevel.easy,
        maximumDifficulty: MissionDifficultyLevel.moderate,
      ),
      profile: _profile,
      recoveryActive: true,
    );
    expect(decision.outcome, SafetyOutcome.allowedWithModification);
    expect(decision.modifiedDifficulty, MissionDifficultyLevel.easy);
  });

  test('manual intensity cap allows-with-modification when the mission can '
      'scale down to it', () {
    final profile = _profile.copyWith(
      manualIntensityCap: MissionDifficultyLevel.easy,
    );
    final decision = MissionSafetyPolicy.evaluate(
      mission: _mission(
        baseDifficulty: MissionDifficultyLevel.moderate,
        minimumDifficulty: MissionDifficultyLevel.easy,
        maximumDifficulty: MissionDifficultyLevel.moderate,
      ),
      profile: profile,
      recoveryActive: false,
    );
    expect(decision.outcome, SafetyOutcome.allowedWithModification);
    expect(decision.modifiedDifficulty, MissionDifficultyLevel.easy);
    expect(decision.reasonCodes, contains('exceedsIntensityCap'));
  });

  test('manual intensity cap denies when the mission cannot scale down to '
      'it', () {
    final profile = _profile.copyWith(
      manualIntensityCap: MissionDifficultyLevel.restorative,
    );
    final decision = MissionSafetyPolicy.evaluate(
      mission: _mission(
        baseDifficulty: MissionDifficultyLevel.moderate,
        minimumDifficulty: MissionDifficultyLevel.easy,
        maximumDifficulty: MissionDifficultyLevel.moderate,
      ),
      profile: profile,
      recoveryActive: false,
    );
    expect(decision.isDenied, isTrue);
    expect(decision.reasonCodes, contains('exceedsIntensityCap'));
  });

  test('a caution-classified, challenging-or-above mission is denied for a '
      'low fitness self-assessment', () {
    final profile = _profile.copyWith(
      fitnessSelfAssessment: FitnessSelfAssessment.low,
    );
    final decision = MissionSafetyPolicy.evaluate(
      mission: _mission(
        baseDifficulty: MissionDifficultyLevel.challenging,
        minimumDifficulty: MissionDifficultyLevel.challenging,
        maximumDifficulty: MissionDifficultyLevel.challenging,
        safetyClassification: SafetyClassification.requiresCaution,
      ),
      profile: profile,
      recoveryActive: false,
    );
    expect(decision.isDenied, isTrue);
    expect(decision.reasonCodes, contains('unsafeFitnessVolume'));
  });

  test('a safe, ordinary mission is allowed outright', () {
    final decision = MissionSafetyPolicy.evaluate(
      mission: _mission(),
      profile: _profile,
      recoveryActive: false,
    );
    expect(decision.outcome, SafetyOutcome.allowed);
    expect(decision.reasonCodes, isEmpty);
  });
}
