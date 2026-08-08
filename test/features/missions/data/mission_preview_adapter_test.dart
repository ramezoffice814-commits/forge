import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/dashboard/domain/entities/mission_preview.dart';
import 'package:forge/features/missions/data/mission_preview_adapter.dart';
import 'package:forge/features/missions/domain/entities/mission_instance.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/missions/domain/enums/proof_policy.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_definition.dart';

void main() {
  group('toLegacyDifficulty', () {
    test('maps the 5-level engine scale down to the 3-level UI scale', () {
      expect(
        toLegacyDifficulty(MissionDifficultyLevel.restorative),
        MissionDifficulty.easy,
      );
      expect(
        toLegacyDifficulty(MissionDifficultyLevel.easy),
        MissionDifficulty.easy,
      );
      expect(
        toLegacyDifficulty(MissionDifficultyLevel.moderate),
        MissionDifficulty.moderate,
      );
      expect(
        toLegacyDifficulty(MissionDifficultyLevel.challenging),
        MissionDifficulty.hard,
      );
      expect(
        toLegacyDifficulty(MissionDifficultyLevel.advanced),
        MissionDifficulty.hard,
      );
    });
  });

  test('missionPreviewFromInstance carries every mission fact through '
      'unchanged', () {
    final instance = MissionInstance(
      instanceId: 'inst-1',
      definitionId: 'def-1',
      assignedDate: DateTime.utc(2026, 8, 10),
      title: 'Read for 5 Minutes',
      description: 'Five minutes with a book.',
      category: MissionCategory.reading,
      resolvedDifficulty: MissionDifficultyLevel.easy,
      resolvedDuration: 5,
      xpHint: 15,
      progressDefinition: const BinaryProgressDefinition(),
      completionConditions: const ['Read for 5 minutes'],
      proofPolicy: ProofPolicy.required,
      selectionReasons: const ['Fits your 5-minute availability.'],
      engineVersion: '1.0.0',
      recoveryMission: true,
    );

    final preview = missionPreviewFromInstance(
      instance,
      transmissionAvailable: true,
    );

    expect(preview.id, 'inst-1');
    expect(preview.title, 'Read for 5 Minutes');
    expect(preview.subtitle, 'Five minutes with a book.');
    expect(preview.category, 'Reading');
    expect(preview.difficulty, MissionDifficulty.easy);
    expect(preview.estimatedMinutes, 5);
    expect(preview.xpReward, 15);
    expect(preview.status, MissionStatus.notStarted);
    expect(preview.transmissionAvailable, isTrue);
    expect(preview.requiresProof, isTrue);
    expect(preview.completionConditions, ['Read for 5 minutes']);
    expect(preview.selectionReasons, ['Fits your 5-minute availability.']);
  });

  test('a "none" proof policy maps to requiresProof=false', () {
    final instance = MissionInstance(
      instanceId: 'inst-2',
      definitionId: 'def-2',
      assignedDate: DateTime.utc(2026, 8, 10),
      title: 'Title',
      description: 'Description',
      category: MissionCategory.hydration,
      resolvedDifficulty: MissionDifficultyLevel.restorative,
      resolvedDuration: 2,
      xpHint: 5,
      progressDefinition: const BinaryProgressDefinition(),
      completionConditions: const ['Drink water'],
      proofPolicy: ProofPolicy.none,
      selectionReasons: const [],
      engineVersion: '1.0.0',
    );
    final preview = missionPreviewFromInstance(
      instance,
      transmissionAvailable: true,
    );
    expect(preview.requiresProof, isFalse);
  });
}
