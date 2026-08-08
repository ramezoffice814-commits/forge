import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/domain/enums/completion_quality.dart';
import 'package:forge/features/competition/domain/enums/completion_validation_state.dart';
import 'package:forge/features/competition/domain/enums/competition_integrity_state.dart';
import 'package:forge/features/competition/domain/policies/competition_scoring_constants.dart';
import 'package:forge/features/competition/domain/policies/forge_competitive_score_policy.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';

import '../../../support/competition_test_helpers.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);

  test('an invalid completion scores exactly zero, not just less', () {
    final result = ForgeCompetitiveScorePolicy.evaluate(
      summary: testCompetitiveSummary(
        completedAt: now,
        validationState: CompletionValidationState.invalid,
      ),
      priorCompletionsInCategoryThisWeek: 0,
    );
    expect(result.finalScorePreview, 0);
  });

  test('an excluded (integrity) completion scores exactly zero', () {
    final result = ForgeCompetitiveScorePolicy.evaluate(
      summary: testCompetitiveSummary(
        completedAt: now,
        eventIntegrityState: CompetitionIntegrityState.excluded,
      ),
      priorCompletionsInCategoryThisWeek: 0,
    );
    expect(result.finalScorePreview, 0);
  });

  test('an unverified completion is not treated as valid', () {
    final result = ForgeCompetitiveScorePolicy.evaluate(
      summary: testCompetitiveSummary(
        completedAt: now,
        validationState: CompletionValidationState.unverified,
      ),
      priorCompletionsInCategoryThisWeek: 0,
    );
    expect(result.finalScorePreview, 0);
  });

  test(
    'a harder difficulty scores higher than an easier one, all else equal',
    () {
      final restorative = ForgeCompetitiveScorePolicy.evaluate(
        summary: testCompetitiveSummary(
          completedAt: now,
          difficulty: MissionDifficultyLevel.restorative,
        ),
        priorCompletionsInCategoryThisWeek: 0,
      );
      final advanced = ForgeCompetitiveScorePolicy.evaluate(
        summary: testCompetitiveSummary(
          completedAt: now,
          difficulty: MissionDifficultyLevel.advanced,
        ),
        priorCompletionsInCategoryThisWeek: 0,
      );
      expect(
        restorative.finalScorePreview,
        lessThan(advanced.finalScorePreview),
      );
    },
  );

  test('a higher completion quality scores higher, all else equal', () {
    final low = ForgeCompetitiveScorePolicy.evaluate(
      summary: testCompetitiveSummary(
        completedAt: now,
        completionQuality: CompletionQuality.low,
      ),
      priorCompletionsInCategoryThisWeek: 0,
    );
    final high = ForgeCompetitiveScorePolicy.evaluate(
      summary: testCompetitiveSummary(
        completedAt: now,
        completionQuality: CompletionQuality.high,
      ),
      priorCompletionsInCategoryThisWeek: 0,
    );
    expect(low.finalScorePreview, lessThan(high.finalScorePreview));
  });

  test('the first completion in a category this week scores a bonus over '
      'a heavily-repeated one', () {
    final first = ForgeCompetitiveScorePolicy.evaluate(
      summary: testCompetitiveSummary(completedAt: now),
      priorCompletionsInCategoryThisWeek: 0,
    );
    final dominant = ForgeCompetitiveScorePolicy.evaluate(
      summary: testCompetitiveSummary(completedAt: now),
      priorCompletionsInCategoryThisWeek: 10,
    );
    expect(dominant.finalScorePreview, lessThan(first.finalScorePreview));
  });

  test('repeating the same mission recently produces diminishing returns', () {
    final fresh = ForgeCompetitiveScorePolicy.evaluate(
      summary: testCompetitiveSummary(
        completedAt: now,
        repeatedMissionCount: 0,
      ),
      priorCompletionsInCategoryThisWeek: 0,
    );
    final repeatedOnce = ForgeCompetitiveScorePolicy.evaluate(
      summary: testCompetitiveSummary(
        completedAt: now,
        repeatedMissionCount: 1,
      ),
      priorCompletionsInCategoryThisWeek: 0,
    );
    final repeatedMany = ForgeCompetitiveScorePolicy.evaluate(
      summary: testCompetitiveSummary(
        completedAt: now,
        repeatedMissionCount: 10,
      ),
      priorCompletionsInCategoryThisWeek: 0,
    );
    expect(repeatedOnce.finalScorePreview, lessThan(fresh.finalScorePreview));
    expect(
      repeatedMany.finalScorePreview,
      lessThanOrEqualTo(repeatedOnce.finalScorePreview),
    );
    expect(repeatedMany.finalScorePreview, greaterThanOrEqualTo(0));
  });

  test('a recovery mission never scores more than the same mission would '
      'as a normal completion', () {
    final normal = ForgeCompetitiveScorePolicy.evaluate(
      summary: testCompetitiveSummary(completedAt: now, recoveryMission: false),
      priorCompletionsInCategoryThisWeek: 0,
    );
    final recovery = ForgeCompetitiveScorePolicy.evaluate(
      summary: testCompetitiveSummary(completedAt: now, recoveryMission: true),
      priorCompletionsInCategoryThisWeek: 0,
    );
    expect(
      recovery.finalScorePreview,
      lessThanOrEqualTo(normal.finalScorePreview),
    );
    expect(
      recovery.finalScorePreview,
      greaterThan(0),
    ); // never humiliated to zero.
  });

  test(
    'a warning-level integrity state reduces but does not zero the score',
    () {
      final clean = ForgeCompetitiveScorePolicy.evaluate(
        summary: testCompetitiveSummary(completedAt: now),
        priorCompletionsInCategoryThisWeek: 0,
      );
      final warning = ForgeCompetitiveScorePolicy.evaluate(
        summary: testCompetitiveSummary(
          completedAt: now,
          eventIntegrityState: CompetitionIntegrityState.warning,
        ),
        priorCompletionsInCategoryThisWeek: 0,
      );
      expect(warning.finalScorePreview, lessThan(clean.finalScorePreview));
      expect(warning.finalScorePreview, greaterThan(0));
    },
  );

  test('a single mission never exceeds the per-mission cap, across a wide '
      'input sweep', () {
    for (final difficulty in MissionDifficultyLevel.values) {
      for (final quality in CompletionQuality.values) {
        for (final priorInCategory in [0, 3, 10, 50]) {
          for (final repeated in [0, 1, 5, 20]) {
            final result = ForgeCompetitiveScorePolicy.evaluate(
              summary: testCompetitiveSummary(
                completedAt: now,
                difficulty: difficulty,
                completionQuality: quality,
                repeatedMissionCount: repeated,
              ),
              priorCompletionsInCategoryThisWeek: priorInCategory,
            );
            expect(
              result.finalScorePreview,
              lessThanOrEqualTo(CompetitionScoringConstants.maxScorePerMission),
            );
            expect(result.finalScorePreview, greaterThanOrEqualTo(0));
          }
        }
      }
    }
  });

  test('identical inputs always produce an identical result (determinism)', () {
    final summary = testCompetitiveSummary(completedAt: now);
    final a = ForgeCompetitiveScorePolicy.evaluate(
      summary: summary,
      priorCompletionsInCategoryThisWeek: 2,
    );
    final b = ForgeCompetitiveScorePolicy.evaluate(
      summary: summary,
      priorCompletionsInCategoryThisWeek: 2,
    );
    expect(a.finalScorePreview, b.finalScorePreview);
    expect(a.reasons, b.reasons);
  });

  test('every evaluation is marked provisionalOnly', () {
    final result = ForgeCompetitiveScorePolicy.evaluate(
      summary: testCompetitiveSummary(completedAt: now),
      priorCompletionsInCategoryThisWeek: 0,
    );
    expect(result.provisionalOnly, isTrue);
  });
}
