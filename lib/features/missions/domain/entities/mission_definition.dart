import 'package:flutter/foundation.dart';

import '../enums/mission_category.dart';
import '../enums/mission_difficulty_level.dart';
import '../enums/proof_policy.dart';
import '../enums/safety_classification.dart';
import '../progress/mission_progress_type.dart';

/// One curated catalog entry. Every field is plain data — no executable
/// logic, no templating engine — because the catalog itself must stay
/// auditable and safe: an AI (later) may rewrite dialogue *around* a
/// mission, but it never invents the mission itself.
@immutable
class MissionDefinition {
  const MissionDefinition({
    required this.id,
    required this.version,
    required this.title,
    required this.description,
    required this.category,
    required this.baseDifficulty,
    required this.minimumDifficulty,
    required this.maximumDifficulty,
    required this.estimatedMinutes,
    required this.minimumMinutes,
    required this.maximumMinutes,
    required this.baseXpHint,
    required this.completionConditions,
    required this.proofPolicy,
    required this.safetyClassification,
    required this.recoveryEligible,
    required this.repeatCooldownDays,
    required this.maximumOccurrencesPerWeek,
    required this.active,
    this.progressType = MissionProgressType.binary,
    this.progressTarget,
    this.subcategory,
    this.tags = const {},
    this.requiredCapabilities = const {},
    this.excludedConditions = const {},
    this.allowedGoalTypes = const {},
    this.accessibilityAlternativeId,
    this.progressionGroup,
    this.progressionStep,
    this.localeKey = 'en',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final int version;
  final String title;
  final String description;
  final MissionCategory category;
  final String? subcategory;

  final MissionDifficultyLevel baseDifficulty;
  final MissionDifficultyLevel minimumDifficulty;
  final MissionDifficultyLevel maximumDifficulty;

  final int estimatedMinutes;
  final int minimumMinutes;
  final int maximumMinutes;

  /// Display-only — never authoritative. See the engine's trust-boundary
  /// note: a future backend must revalidate before granting real XP.
  final int baseXpHint;

  final Set<String> tags;
  final Set<String> requiredCapabilities;

  /// User-declared health/accessibility tags (from
  /// `UserDisciplineProfile.healthLimitations`/`accessibilityNeeds`) that
  /// disqualify this mission outright.
  final Set<String> excludedConditions;
  final Set<String> allowedGoalTypes;
  final List<String> completionConditions;
  final ProofPolicy proofPolicy;
  final SafetyClassification safetyClassification;

  /// A gentler catalog entry to substitute when this one doesn't fit an
  /// accessibility need — a reference, not an inline alternate definition,
  /// so the alternative is itself a fully independent, validated entry.
  final String? accessibilityAlternativeId;

  final bool recoveryEligible;
  final int repeatCooldownDays;
  final int maximumOccurrencesPerWeek;

  /// Missions sharing a `progressionGroup` form a track (e.g.
  /// push-ups: 5 → 10 → 15); `progressionStep` orders them within it.
  final String? progressionGroup;
  final int? progressionStep;

  final bool active;
  final String localeKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Which progress control/validation shape this mission uses. Defaults
  /// to [MissionProgressType.binary] ("explicit completion action
  /// recorded") — the safe, always-valid fallback for a catalog entry that
  /// doesn't need anything more specific.
  final MissionProgressType progressType;

  /// Meaning depends on [progressType]: target count/quantity/servings, a
  /// reflection's minimum length, or a percentage threshold. Null for
  /// types that derive their target elsewhere (timer/reading/codingSession
  /// use the resolved mission duration; checklist uses
  /// [completionConditions] as its items; binary needs no target).
  final int? progressTarget;
}
