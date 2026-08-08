import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/data/mock/mock_mission_context.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/missions/domain/enums/rejection_reason.dart';
import 'package:forge/features/missions/presentation/providers/mission_providers.dart';
import 'package:forge/features/missions/presentation/providers/mission_selection_controller.dart';
import 'package:forge/features/missions/presentation/providers/mission_selection_state.dart';

Future<void> _waitReady(ProviderContainer container) async {
  await container.read(missionSelectionControllerProvider.notifier).ready;
}

void main() {
  ProviderContainer buildContainer({
    MockMissionContextScenario scenario =
        MockMissionContextScenario.normalActive,
    bool catalogUnavailable = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        missionMockScenarioProvider.overrideWithValue(scenario),
        missionCatalogUnavailableProvider.overrideWithValue(catalogUnavailable),
      ],
    );
    return container;
  }

  test(
    'build() resolves to a Ready state with a real selected mission',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      await _waitReady(container);
      final state = container.read(missionSelectionControllerProvider);
      expect(state, isA<MissionSelectionReady>());
    },
  );

  test(
    'an unavailable catalog resolves to an Error state, not a crash',
    () async {
      final container = buildContainer(catalogUnavailable: true);
      addTearDown(container.dispose);

      await _waitReady(container);
      expect(
        container.read(missionSelectionControllerProvider),
        isA<MissionSelectionError>(),
      );
    },
  );

  test('retry() recovers once the underlying condition clears', () async {
    final container = buildContainer(catalogUnavailable: true);
    addTearDown(container.dispose);
    await _waitReady(container);
    expect(
      container.read(missionSelectionControllerProvider),
      isA<MissionSelectionError>(),
    );

    container.updateOverrides([
      missionMockScenarioProvider.overrideWithValue(
        MockMissionContextScenario.normalActive,
      ),
      missionCatalogUnavailableProvider.overrideWithValue(false),
    ]);
    await container.read(missionSelectionControllerProvider.notifier).retry();

    expect(
      container.read(missionSelectionControllerProvider),
      isA<MissionSelectionReady>(),
    );
  });

  test(
    'requestEasierMission caps difficulty below whatever was resolved',
    () async {
      final container = buildContainer(
        scenario: MockMissionContextScenario.categoryPreference,
      );
      addTearDown(container.dispose);
      await _waitReady(container);

      final notifier = container.read(
        missionSelectionControllerProvider.notifier,
      );
      final before =
          (container.read(missionSelectionControllerProvider)
                  as MissionSelectionReady)
              .result;

      await notifier.requestEasierMission();

      final after =
          (container.read(missionSelectionControllerProvider)
                  as MissionSelectionReady)
              .result;
      expect(
        after.resolvedDifficulty.index,
        lessThan(before.resolvedDifficulty.index),
      );
    },
  );

  test(
    'requestCategory restricts subsequent selection to that category',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      await _waitReady(container);

      final notifier = container.read(
        missionSelectionControllerProvider.notifier,
      );
      await notifier.requestCategory(MissionCategory.coding);

      final state =
          container.read(missionSelectionControllerProvider)
              as MissionSelectionReady;
      expect(state.result.selectedMission.category, MissionCategory.coding);
    },
  );

  test(
    'reduceAvailableTime lowers the resolved duration accordingly',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      await _waitReady(container);

      final notifier = container.read(
        missionSelectionControllerProvider.notifier,
      );
      await notifier.reduceAvailableTime(5);

      final state =
          container.read(missionSelectionControllerProvider)
              as MissionSelectionReady;
      expect(state.result.resolvedDuration, lessThanOrEqualTo(5));
    },
  );

  test('setRecoveryMode(true) switches the result into recovery', () async {
    final container = buildContainer();
    addTearDown(container.dispose);
    await _waitReady(container);

    final notifier = container.read(
      missionSelectionControllerProvider.notifier,
    );
    await notifier.setRecoveryMode(true);

    final state =
        container.read(missionSelectionControllerProvider)
            as MissionSelectionReady;
    expect(state.result.recoveryApplied, isTrue);
    expect(
      state.result.resolvedDifficulty.index,
      lessThanOrEqualTo(MissionDifficultyLevel.easy.index),
    );
  });

  test(
    'rejectMission excludes the rejected mission from the next pick',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      await _waitReady(container);

      final notifier = container.read(
        missionSelectionControllerProvider.notifier,
      );
      final firstPickId =
          (container.read(missionSelectionControllerProvider)
                  as MissionSelectionReady)
              .result
              .selectedMission
              .id;

      await notifier.rejectMission(RejectionReason.notInMood);

      final state =
          container.read(missionSelectionControllerProvider)
              as MissionSelectionReady;
      expect(state.result.selectedMission.id, isNot(firstPickId));
    },
  );
}
