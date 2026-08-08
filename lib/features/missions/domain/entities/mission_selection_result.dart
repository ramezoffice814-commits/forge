import 'package:flutter/foundation.dart';

import '../enums/mission_difficulty_level.dart';
import 'mission_definition.dart';

/// A candidate the engine looked at but didn't choose, with why — surfaced
/// for debugging/auditability, not shown to end users verbatim.
@immutable
class RejectedCandidate {
  const RejectedCandidate({required this.missionId, required this.reasonCodes});

  final String missionId;
  final List<String> reasonCodes;
}

/// The engine's full, explainable output. [selectedMission] is guaranteed
/// non-null for any supported profile (see [fallbackUsed] for when a
/// universal fallback had to be used instead of an ideal match).
@immutable
class MissionSelectionResult {
  const MissionSelectionResult({
    required this.selectedMission,
    required this.resolvedDifficulty,
    required this.resolvedDuration,
    required this.selectionReasons,
    required this.recoveryApplied,
    required this.fallbackUsed,
    required this.confidence,
    required this.engineVersion,
    this.personalizationVariables = const {},
    this.rejectedCandidatesSummary = const [],
    this.safetyChecks = const [],
    this.fallbackReason,
    this.accessibilityAlternativeUsed = false,
  });

  final MissionDefinition selectedMission;
  final MissionDifficultyLevel resolvedDifficulty;
  final int resolvedDuration;

  final Map<String, String> personalizationVariables;

  /// Concise, user-safe explanation strings — never raw weights or private
  /// history. E.g. "Fits your 15-minute availability."
  final List<String> selectionReasons;

  final List<RejectedCandidate> rejectedCandidatesSummary;

  /// Reason codes for safety checks the selected mission passed.
  final List<String> safetyChecks;

  final bool recoveryApplied;
  final bool accessibilityAlternativeUsed;
  final bool fallbackUsed;
  final String? fallbackReason;

  /// 0–1 — how confident the engine is given available history (thin
  /// history / first-day profiles score lower, not zero).
  final double confidence;

  final String engineVersion;
}
