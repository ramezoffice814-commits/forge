import 'backend_command.dart';

/// Reports raw progress facts (e.g. "12 of 20 reps", "6 of 10 minutes") —
/// [progressPayload] is intentionally opaque to the transport layer and
/// interpreted server-side. Its constructor actively rejects a reward,
/// score, or rank field (see [BackendCommand.assertNoForbiddenFields]),
/// rather than merely documenting that it shouldn't have one.
class RecordMissionProgressCommand extends BackendCommand {
  RecordMissionProgressCommand({
    required super.commandId,
    required super.missionInstanceId,
    required super.userId,
    required super.timestamp,
    required super.sequence,
    required super.idempotencyKey,
    required this.progressPayload,
  }) {
    BackendCommand.assertNoForbiddenFields(progressPayload);
  }

  final Map<String, Object?> progressPayload;
}
