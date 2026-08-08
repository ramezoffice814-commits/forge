import '../entities/mission_catalog_validator.dart';
import '../entities/mission_definition.dart';
import '../entities/user_discipline_profile.dart';
import '../enums/mission_difficulty_level.dart';
import '../enums/safety_classification.dart';

enum SafetyOutcome { allowed, denied, allowedWithModification }

/// A single candidate's safety verdict. A [SafetyOutcome.denied] mission
/// must never re-enter through scoring — the engine drops it entirely and
/// records it in `rejectedCandidatesSummary` instead.
class SafetyDecision {
  const SafetyDecision({
    required this.outcome,
    required this.reasonCodes,
    this.modifiedDifficulty,
  });

  final SafetyOutcome outcome;
  final List<String> reasonCodes;

  /// Set only for [SafetyOutcome.allowedWithModification] — the difficulty
  /// the engine must actually use instead of the mission's own base value.
  final MissionDifficultyLevel? modifiedDifficulty;

  bool get isDenied => outcome == SafetyOutcome.denied;
}

/// Deterministic, testable safety gate — evaluated before any scoring.
/// Nothing here infers medical or psychological state: every input is
/// either catalog data or a user-declared tag (`healthLimitations`,
/// `accessibilityNeeds`, `manualIntensityCap`).
abstract final class MissionSafetyPolicy {
  static SafetyDecision evaluate({
    required MissionDefinition mission,
    required UserDisciplineProfile profile,
    required bool recoveryActive,
  }) {
    if (!mission.active) {
      return const SafetyDecision(
        outcome: SafetyOutcome.denied,
        reasonCodes: ['catalogEntryInactive'],
      );
    }

    if (!MissionCatalogValidator.isValid(mission)) {
      return const SafetyDecision(
        outcome: SafetyOutcome.denied,
        reasonCodes: ['catalogEntryInactive'],
      );
    }

    if (profile.avoidedCategories.contains(mission.category)) {
      return const SafetyDecision(
        outcome: SafetyOutcome.denied,
        reasonCodes: ['prohibitedCategory'],
      );
    }

    final declaredConstraints = {
      ...profile.healthLimitations,
      ...profile.accessibilityNeeds,
    };
    if (mission.excludedConditions
        .intersection(declaredConstraints)
        .isNotEmpty) {
      if (mission.accessibilityAlternativeId == null) {
        return const SafetyDecision(
          outcome: SafetyOutcome.denied,
          reasonCodes: [
            'conflictsWithUserRestriction',
            'missingAccessibilityAlternative',
          ],
        );
      }
      return const SafetyDecision(
        outcome: SafetyOutcome.denied,
        reasonCodes: ['conflictsWithUserRestriction'],
      );
    }

    if (recoveryActive && !mission.recoveryEligible) {
      return const SafetyDecision(
        outcome: SafetyOutcome.denied,
        reasonCodes: ['recoveryIncompatible'],
      );
    }

    // Recovery and the user's own manual cap are two independent ceilings —
    // whichever is *stricter* wins. Computing one effective cap up front
    // (rather than two separate early-return checks) is what makes both
    // constraints hold at once instead of whichever check happened to run
    // first silently overriding the other.
    MissionDifficultyLevel? effectiveCap;
    final reasonForCap = <String>[];
    if (recoveryActive) {
      effectiveCap = MissionDifficultyLevel.easy;
      reasonForCap.add('recoveryIncompatible');
    }
    if (profile.manualIntensityCap != null &&
        (effectiveCap == null ||
            profile.manualIntensityCap!.index < effectiveCap.index)) {
      effectiveCap = profile.manualIntensityCap;
      reasonForCap.add('exceedsIntensityCap');
    }

    if (effectiveCap != null &&
        mission.baseDifficulty.index > effectiveCap.index) {
      if (mission.minimumDifficulty.index <= effectiveCap.index) {
        return SafetyDecision(
          outcome: SafetyOutcome.allowedWithModification,
          reasonCodes: List.of(reasonForCap),
          modifiedDifficulty: effectiveCap,
        );
      }
      return SafetyDecision(
        outcome: SafetyOutcome.denied,
        reasonCodes: List.of(reasonForCap),
      );
    }

    if (mission.safetyClassification == SafetyClassification.requiresCaution &&
        mission.baseDifficulty.index >=
            MissionDifficultyLevel.challenging.index &&
        profile.fitnessSelfAssessment.name == 'low') {
      return const SafetyDecision(
        outcome: SafetyOutcome.denied,
        reasonCodes: ['unsafeFitnessVolume'],
      );
    }

    return const SafetyDecision(
      outcome: SafetyOutcome.allowed,
      reasonCodes: [],
    );
  }
}
