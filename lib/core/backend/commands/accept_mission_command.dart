import 'backend_command.dart';

/// Requests that a mission instance be accepted — carries no reward or
/// state field of any kind; acceptance itself is server-decided.
class AcceptMissionCommand extends BackendCommand {
  const AcceptMissionCommand({
    required super.commandId,
    required super.missionInstanceId,
    required super.userId,
    required super.timestamp,
    required super.sequence,
    required super.idempotencyKey,
  });
}
