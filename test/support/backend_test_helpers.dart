import 'package:forge/core/backend/commands/accept_mission_command.dart';
import 'package:forge/core/backend/commands/record_mission_progress_command.dart';
import 'package:forge/core/backend/commands/submit_mission_command.dart';
import 'package:forge/core/backend/idempotency_key_generator.dart';

const testBackendUserId = 'test-user';
const testMissionInstanceId = 'mission-1';

const _keyGenerator = DeterministicIdempotencyKeyGenerator();

AcceptMissionCommand testAcceptCommand({
  String commandId = 'cmd-accept-1',
  String missionInstanceId = testMissionInstanceId,
  String userId = testBackendUserId,
  required DateTime timestamp,
  int sequence = 1,
  String? idempotencyKey,
}) {
  return AcceptMissionCommand(
    commandId: commandId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    timestamp: timestamp,
    sequence: sequence,
    idempotencyKey:
        idempotencyKey ??
        _keyGenerator.generate(
          missionInstanceId: missionInstanceId,
          commandType: 'accept',
          sequence: sequence,
        ),
  );
}

RecordMissionProgressCommand testProgressCommand({
  String commandId = 'cmd-progress-1',
  String missionInstanceId = testMissionInstanceId,
  String userId = testBackendUserId,
  required DateTime timestamp,
  int sequence = 2,
  String? idempotencyKey,
  Map<String, Object?> progressPayload = const {'percent': 50},
}) {
  return RecordMissionProgressCommand(
    commandId: commandId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    timestamp: timestamp,
    sequence: sequence,
    idempotencyKey:
        idempotencyKey ??
        _keyGenerator.generate(
          missionInstanceId: missionInstanceId,
          commandType: 'progress',
          sequence: sequence,
        ),
    progressPayload: progressPayload,
  );
}

SubmitMissionCommand testSubmitCommand({
  String commandId = 'cmd-submit-1',
  String missionInstanceId = testMissionInstanceId,
  String userId = testBackendUserId,
  required DateTime timestamp,
  int sequence = 3,
  String? idempotencyKey,
  Map<String, Object?> completionPayload = const {'proof': 'done'},
}) {
  return SubmitMissionCommand(
    commandId: commandId,
    missionInstanceId: missionInstanceId,
    userId: userId,
    timestamp: timestamp,
    sequence: sequence,
    idempotencyKey:
        idempotencyKey ??
        _keyGenerator.generate(
          missionInstanceId: missionInstanceId,
          commandType: 'submit',
          sequence: sequence,
        ),
    completionPayload: completionPayload,
  );
}
