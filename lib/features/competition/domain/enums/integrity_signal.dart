/// Individual anti-abuse signals a [CompetitionIntegrityEvaluation] can
/// carry. Signals are additive evidence, not verdicts — the evaluation's
/// own `state` decides whether they add up to a warning or an exclusion.
enum IntegritySignal {
  duplicateCompletion,
  impossibleSequence,
  excessiveVolume,
  repeatedFarming,
  abnormalScoreJump,
  timestampAnomaly,
  invalidValidationState,
  localOnlyUnconfirmed,
}
