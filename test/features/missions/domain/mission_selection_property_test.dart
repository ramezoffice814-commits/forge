// Property-style checks: rather than asserting one exact outcome, these
// sweep a deterministic grid of profile/history combinations against the
// real 38-mission catalog and assert invariants that must hold for *every*
// combination — no unseeded randomness, just an exhaustive fixed sweep.
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/data/catalog/mock_mission_catalog.dart';
import 'package:forge/features/missions/domain/entities/behavioral_history.dart';
import 'package:forge/features/missions/domain/entities/mission_selection_request.dart';
import 'package:forge/features/missions/domain/entities/user_discipline_profile.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/missions/domain/mission_selection_engine.dart';

void main() {
  final catalog = MockMissionCatalog.entries;
  final catalogIds = catalog.map((m) => m.id).toSet();

  final dates = [
    DateTime.utc(2026, 1, 5),
    DateTime.utc(2026, 6, 15),
    DateTime.utc(2026, 12, 31),
  ];
  final availableMinutesOptions = [5, 10, 20, 45, 90];
  final manualCaps = <MissionDifficultyLevel?>[
    null,
    MissionDifficultyLevel.restorative,
    MissionDifficultyLevel.easy,
    MissionDifficultyLevel.moderate,
  ];
  final recoveryOptions = [false, true];
  final userIds = ['user-1', 'user-2', 'user-3'];

  final combinations = <MissionSelectionRequest>[
    for (final userId in userIds)
      for (final date in dates)
        for (final minutes in availableMinutesOptions)
          for (final cap in manualCaps)
            for (final recovery in recoveryOptions)
              MissionSelectionRequest(
                profile: UserDisciplineProfile(
                  userId: userId,
                  availableMinutesToday: minutes,
                  manualIntensityCap: cap,
                  recoveryModeActive: recovery,
                ),
                history: const BehavioralHistory(),
                currentDateTime: date,
                catalog: catalog,
              ),
  ];

  test('invariants hold across every combination in the deterministic sweep '
      '(${combinations.length} combinations)', () {
    for (final request in combinations) {
      final result = MissionSelectionEngine.select(request);

      // Selected mission always belongs to the provided catalog.
      expect(
        catalogIds.contains(result.selectedMission.id),
        isTrue,
        reason: 'mission ${result.selectedMission.id} not in catalog',
      );

      // Duration never exceeds the mission's own bounds, and is never
      // zero/negative.
      expect(result.resolvedDuration, greaterThan(0));
      expect(
        result.resolvedDuration,
        lessThanOrEqualTo(result.selectedMission.maximumMinutes),
      );

      // Manual cap is always respected when set.
      final cap = request.profile.manualIntensityCap;
      if (cap != null) {
        expect(result.resolvedDifficulty.index, lessThanOrEqualTo(cap.index));
      }

      // Recovery result is never above easy.
      if (result.recoveryApplied) {
        expect(
          result.resolvedDifficulty.index,
          lessThanOrEqualTo(MissionDifficultyLevel.easy.index),
        );
      }

      // Hard-rejected missions are never the one selected.
      final rejectedIds = result.rejectedCandidatesSummary
          .map((r) => r.missionId)
          .toSet();
      expect(rejectedIds.contains(result.selectedMission.id), isFalse);

      // Confidence and duration are always sane numeric values.
      expect(result.confidence, inInclusiveRange(0.0, 1.0));
      expect(result.resolvedDuration.isFinite, isTrue);

      // Same input always gives the same result.
      final repeat = MissionSelectionEngine.select(request);
      expect(repeat.selectedMission.id, result.selectedMission.id);
      expect(repeat.resolvedDifficulty, result.resolvedDifficulty);
      expect(repeat.resolvedDuration, result.resolvedDuration);
    }
  });

  test(
    'the engine never throws for any empty-history profile in the sweep',
    () {
      for (final request in combinations) {
        expect(() => MissionSelectionEngine.select(request), returnsNormally);
      }
    },
  );
}
