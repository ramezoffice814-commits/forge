// Dart/SQL parity harness (Roadmap Item 13, step 23) — starts with the one
// scenario already independently pinned on both sides:
//
// - Server side: supabase/tests/010_reward_calculation_and_privacy.sql
//   completes a brand-new user's very first mission
//   ('fitness-10min-stretch': category=fitness, difficulty=easy,
//   base_xp_hint=12) through the real forge_submit_mission RPC and asserts
//   `confirmedXpReward = 12` and `xp_ledger.amount = 12`. Re-run against the
//   live staging project during this same Item 13 pass — passed.
// - Client side: this test runs the identical inputs (baseXpHint=12,
//   difficulty=easy, zero prior history — no streak, no category tier, no
//   recovery, no repeat) through XpCalculationPolicy.evaluate directly and
//   asserts the same result.
//
// Both sides collapse to the same formula for this scenario:
//   round(baseXpHint * difficultyMultiplier(easy)=1.0 * categoryMultiplier
//   (beginner)=1.0) = round(12 * 1.0 * 1.0) = 12, with every bonus/penalty
//   term at zero.
//
// This is intentionally a single deterministic fixture, not a fuzzer: it
// exists to catch the specific, high-consequence failure mode where the
// two formulas silently drift apart (e.g. a difficulty multiplier changed
// on one side but not the other) rather than to exhaustively cross-check
// every input combination. Broader fixture coverage (varying difficulty,
// category tier, streak, recovery, repeat count against equivalent SQL
// scenarios) remains a documented gap for a follow-up pass — seeding
// synthetic staging state for each variant and re-running
// forge_submit_mission is meaningfully more setup than this one pinned
// case, and wasn't justified within this pass's time budget.
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/progression/domain/entities/completed_mission_summary.dart';
import 'package:forge/features/progression/domain/entities/mission_history_snapshot.dart';
import 'package:forge/features/progression/domain/policies/xp_calculation_policy.dart';

void main() {
  test('a brand-new user\'s first easy-fitness completion (baseXpHint=12) '
      'matches the confirmedXpReward the staging server computed for the '
      'identical scenario in 010_reward_calculation_and_privacy.sql', () {
    final summary = CompletedMissionSummary(
      missionInstanceId: 'parity-fixture-mission',
      definitionId: 'fitness-10min-stretch',
      userId: 'parity-fixture-user',
      category: MissionCategory.fitness,
      difficulty: MissionDifficultyLevel.easy,
      baseXpHint: 12,
      resolvedDurationMinutes: 10,
      recoveryMission: false,
      completedAt: DateTime.utc(2026, 1, 1),
    );

    final evaluation = XpCalculationPolicy.evaluate(
      summary: summary,
      snapshot: const MissionHistorySnapshot.empty(),
    );

    expect(
      evaluation.finalXpPreview,
      12,
      reason:
          'Client XpCalculationPolicy and server forge_calculate_xp_reward '
          'must agree on this pinned scenario — a mismatch here means the '
          'two formulas have silently drifted apart.',
    );
  });
}
