import 'package:forge/features/missions/domain/entities/mission_instance.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/missions/domain/enums/proof_policy.dart';
import 'package:forge/features/missions/domain/events/mission_event_source.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_definition.dart';
import 'package:forge/features/missions/domain/sessions/mission_clock.dart';

/// A minimal, deterministic [MissionInstance] for domain/presentation tests
/// that don't care about catalog-specific details — only [instanceId] and
/// [progressDefinition] usually matter to the code under test.
MissionInstance testMissionInstance({
  String instanceId = 'test-instance-1',
  MissionProgressDefinition progressDefinition =
      const BinaryProgressDefinition(),
}) {
  return MissionInstance(
    instanceId: instanceId,
    definitionId: 'test-def',
    assignedDate: DateTime.utc(2026, 8, 10),
    title: 'Test Mission',
    description: 'A mission used only in tests.',
    category: MissionCategory.fitness,
    resolvedDifficulty: MissionDifficultyLevel.easy,
    resolvedDuration: 10,
    xpHint: 20,
    completionConditions: const ['Do the thing'],
    proofPolicy: ProofPolicy.none,
    selectionReasons: const [],
    engineVersion: '1.0.0-test',
    progressDefinition: progressDefinition,
  );
}

/// A controllable clock for session/timing tests — avoids any dependency on
/// wall-clock time or `Future.delayed`.
class FakeMissionClock implements MissionClock {
  FakeMissionClock([DateTime? start])
    : _now = start ?? DateTime.utc(2026, 8, 10, 9);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);
}

const testUserId = 'test-user';
const testSource = MissionEventSource.userAction;
