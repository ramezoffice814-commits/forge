import 'package:flutter/foundation.dart';

import 'mission_definition.dart';

/// Factor-level breakdown for one candidate — kept explicit (rather than a
/// single opaque total) so scoring is debuggable and testable per factor.
/// Weights live centrally in `PersonalizationScorer.weights`; they are
/// product defaults, not scientifically validated constants.
@immutable
class MissionCandidateScore {
  const MissionCandidateScore({
    required this.mission,
    required this.factorScores,
    required this.total,
  });

  final MissionDefinition mission;

  /// Factor name -> raw (pre-weight) score in [0, 1].
  final Map<String, double> factorScores;
  final double total;
}
