import 'backend_command.dart';

class StartMissionCommand extends BackendCommand {
  const StartMissionCommand({
    required super.commandId,
    required super.missionInstanceId,
    required super.userId,
    required super.timestamp,
    required super.sequence,
    required super.idempotencyKey,
  });
}
