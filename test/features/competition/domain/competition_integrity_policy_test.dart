import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/domain/enums/completion_validation_state.dart';
import 'package:forge/features/competition/domain/enums/competition_integrity_state.dart';
import 'package:forge/features/competition/domain/enums/integrity_signal.dart';
import 'package:forge/features/competition/domain/policies/competition_integrity_policy.dart';
import 'package:forge/features/competition/domain/policies/competition_scoring_constants.dart';

import '../../../support/competition_test_helpers.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10, 12);

  test('a clean, well-spaced, valid completion is clean', () {
    final result = CompetitionIntegrityPolicy.evaluateCompletion(
      summary: testCompetitiveSummary(completedAt: now),
      now: now,
      isDuplicate: false,
      previousCompletionAt: now.subtract(const Duration(hours: 1)),
      completionsTodayIncludingThis: 1,
    );
    expect(result.state, CompetitionIntegrityState.clean);
  });

  test('a duplicate completion is excluded', () {
    final result = CompetitionIntegrityPolicy.evaluateCompletion(
      summary: testCompetitiveSummary(completedAt: now),
      now: now,
      isDuplicate: true,
      completionsTodayIncludingThis: 1,
    );
    expect(result.state, CompetitionIntegrityState.excluded);
    expect(result.signals, contains(IntegritySignal.duplicateCompletion));
  });

  test('an invalid validation state is excluded', () {
    final result = CompetitionIntegrityPolicy.evaluateCompletion(
      summary: testCompetitiveSummary(
        completedAt: now,
        validationState: CompletionValidationState.invalid,
      ),
      now: now,
      isDuplicate: false,
      completionsTodayIncludingThis: 1,
    );
    expect(result.state, CompetitionIntegrityState.excluded);
  });

  test('a future-dated completion is an excluded timestamp anomaly', () {
    final result = CompetitionIntegrityPolicy.evaluateCompletion(
      summary: testCompetitiveSummary(
        completedAt: now.add(const Duration(hours: 1)),
      ),
      now: now,
      isDuplicate: false,
      completionsTodayIncludingThis: 1,
    );
    expect(result.state, CompetitionIntegrityState.excluded);
    expect(result.signals, contains(IntegritySignal.timestampAnomaly));
  });

  test('two completions too close together are a warning-level impossible '
      'sequence', () {
    final result = CompetitionIntegrityPolicy.evaluateCompletion(
      summary: testCompetitiveSummary(completedAt: now),
      now: now,
      isDuplicate: false,
      previousCompletionAt: now.subtract(const Duration(seconds: 2)),
      completionsTodayIncludingThis: 1,
    );
    expect(result.state, CompetitionIntegrityState.warning);
    expect(result.signals, contains(IntegritySignal.impossibleSequence));
  });

  test('excessive daily volume is a warning', () {
    final result = CompetitionIntegrityPolicy.evaluateCompletion(
      summary: testCompetitiveSummary(completedAt: now),
      now: now,
      isDuplicate: false,
      completionsTodayIncludingThis:
          CompetitionScoringConstants.excessiveDailyVolumeThreshold + 1,
    );
    expect(result.state, CompetitionIntegrityState.warning);
    expect(result.signals, contains(IntegritySignal.excessiveVolume));
  });

  test('heavy repeated-mission farming is a warning', () {
    final result = CompetitionIntegrityPolicy.evaluateCompletion(
      summary: testCompetitiveSummary(
        completedAt: now,
        repeatedMissionCount:
            CompetitionScoringConstants.repeatedFarmingThreshold,
      ),
      now: now,
      isDuplicate: false,
      completionsTodayIncludingThis: 1,
    );
    expect(result.state, CompetitionIntegrityState.warning);
    expect(result.signals, contains(IntegritySignal.repeatedFarming));
  });

  test('an abnormal jump versus recent history is a warning', () {
    final result = CompetitionIntegrityPolicy.evaluateCompletion(
      summary: testCompetitiveSummary(completedAt: now, provisionalXp: 500),
      now: now,
      isDuplicate: false,
      completionsTodayIncludingThis: 1,
      historicalAverageProvisionalXp: 20,
    );
    expect(result.state, CompetitionIntegrityState.warning);
    expect(result.signals, contains(IntegritySignal.abnormalScoreJump));
  });

  test(
    'local-only-unconfirmed is always present but never escalates alone',
    () {
      final result = CompetitionIntegrityPolicy.evaluateCompletion(
        summary: testCompetitiveSummary(completedAt: now),
        now: now,
        isDuplicate: false,
        completionsTodayIncludingThis: 1,
      );
      expect(result.signals, contains(IntegritySignal.localOnlyUnconfirmed));
      expect(result.state, CompetitionIntegrityState.clean);
    },
  );
}
