import 'backend_command.dart';

/// Requests final submission/completion — [completionPayload] carries
/// only completion/proof facts (e.g. final progress snapshot, proof
/// reference), never a computed reward; its constructor actively rejects
/// one (see [BackendCommand.assertNoForbiddenFields]). The server alone
/// decides XP, achievements, competitive score, and league movement in
/// response.
class SubmitMissionCommand extends BackendCommand {
  SubmitMissionCommand({
    required super.commandId,
    required super.missionInstanceId,
    required super.userId,
    required super.timestamp,
    required super.sequence,
    required super.idempotencyKey,
    required this.completionPayload,
  }) {
    BackendCommand.assertNoForbiddenFields(completionPayload);
  }

  final Map<String, Object?> completionPayload;
}
