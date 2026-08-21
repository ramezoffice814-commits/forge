import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/commands/accept_mission_command.dart';
import 'package:forge/core/backend/commands/backend_command.dart';
import 'package:forge/core/backend/commands/cancel_mission_command.dart';
import 'package:forge/core/backend/commands/record_mission_progress_command.dart';
import 'package:forge/core/backend/commands/start_mission_command.dart';
import 'package:forge/core/backend/commands/submit_mission_command.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);

  test('every reward-shaped field name is on the forbidden list', () {
    const forbidden = BackendCommand.forbiddenClientFields;
    for (final name in [
      'xp',
      'xpReward',
      'level',
      'competitiveScore',
      'rank',
      'leaguePlacement',
      'achievementUnlocked',
      'seasonReward',
    ]) {
      expect(forbidden, contains(name));
    }
  });

  test('every command carries the required base fields', () {
    final commands = <BackendCommand>[
      AcceptMissionCommand(
        commandId: 'c1',
        missionInstanceId: 'm1',
        userId: 'u1',
        timestamp: now,
        sequence: 1,
        idempotencyKey: 'm1:accept:1',
      ),
      StartMissionCommand(
        commandId: 'c2',
        missionInstanceId: 'm1',
        userId: 'u1',
        timestamp: now,
        sequence: 2,
        idempotencyKey: 'm1:start:2',
      ),
      RecordMissionProgressCommand(
        commandId: 'c3',
        missionInstanceId: 'm1',
        userId: 'u1',
        timestamp: now,
        sequence: 3,
        idempotencyKey: 'm1:progress:3',
        progressPayload: const {'percent': 50},
      ),
      SubmitMissionCommand(
        commandId: 'c4',
        missionInstanceId: 'm1',
        userId: 'u1',
        timestamp: now,
        sequence: 4,
        idempotencyKey: 'm1:submit:4',
        completionPayload: const {'proof': 'x'},
      ),
      CancelMissionCommand(
        commandId: 'c5',
        missionInstanceId: 'm1',
        userId: 'u1',
        timestamp: now,
        sequence: 5,
        idempotencyKey: 'm1:cancel:5',
      ),
    ];

    for (final command in commands) {
      expect(command.commandId, isNotEmpty);
      expect(command.missionInstanceId, isNotEmpty);
      expect(command.userId, isNotEmpty);
      expect(command.sequence, greaterThan(0));
      expect(command.idempotencyKey, isNotEmpty);
    }
  });

  test('a progress payload smuggling a forbidden reward field is rejected '
      'at construction time, not silently accepted', () {
    expect(
      () => RecordMissionProgressCommand(
        commandId: 'c1',
        missionInstanceId: 'm1',
        userId: 'u1',
        timestamp: now,
        sequence: 1,
        idempotencyKey: 'm1:progress:1',
        progressPayload: const {'percent': 50, 'xp': 9999},
      ),
      throwsArgumentError,
    );
  });

  test('a submission payload smuggling a forbidden reward field is '
      'rejected at construction time', () {
    expect(
      () => SubmitMissionCommand(
        commandId: 'c1',
        missionInstanceId: 'm1',
        userId: 'u1',
        timestamp: now,
        sequence: 1,
        idempotencyKey: 'm1:submit:1',
        completionPayload: const {'proof': 'x', 'competitiveScore': 500},
      ),
      throwsArgumentError,
    );
  });

  test('a clean progress payload with no forbidden keys is accepted', () {
    final command = RecordMissionProgressCommand(
      commandId: 'c1',
      missionInstanceId: 'm1',
      userId: 'u1',
      timestamp: now,
      sequence: 1,
      idempotencyKey: 'm1:progress:1',
      progressPayload: const {'percent': 50},
    );
    expect(command.progressPayload['percent'], 50);
  });
}
