import 'backend_command.dart';

class CancelMissionCommand extends BackendCommand {
  const CancelMissionCommand({
    required super.commandId,
    required super.missionInstanceId,
    required super.userId,
    required super.timestamp,
    required super.sequence,
    required super.idempotencyKey,
    this.reason,
  });

  final String? reason;
}
