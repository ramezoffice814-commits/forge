import 'backend_client.dart';
import 'commands/accept_mission_command.dart';
import 'commands/backend_command.dart';
import 'commands/cancel_mission_command.dart';
import 'commands/record_mission_progress_command.dart';
import 'commands/start_mission_command.dart';
import 'commands/submit_mission_command.dart';
import 'raw_backend_response.dart';
import 'responses/mission_accepted_server_result.dart';
import 'responses/mission_progress_server_result.dart';
import 'responses/mission_submission_server_result.dart';

/// Wraps a [BackendClient] with the authenticated session's identity and
/// refuses to forward any command whose [BackendCommand.userId] doesn't
/// match it — the one place "context-derived identity" (spec section 3)
/// is actually enforced, so no call site can accidentally forward a
/// command built for a different user.
class AuthenticatedBackendClient implements BackendClient {
  const AuthenticatedBackendClient(this._client, this.authenticatedUserId);

  final BackendClient _client;
  final String authenticatedUserId;

  void _assertOwnership(BackendCommand command) {
    if (command.userId != authenticatedUserId) {
      throw StateError(
        'Refusing to forward a command for userId "${command.userId}" — '
        'the authenticated session is "$authenticatedUserId".',
      );
    }
  }

  @override
  Future<RawBackendResponse<MissionAcceptedServerResult>> acceptMission(
    AcceptMissionCommand command,
  ) {
    _assertOwnership(command);
    return _client.acceptMission(command);
  }

  @override
  Future<RawBackendResponse<MissionAcceptedServerResult>> startMission(
    StartMissionCommand command,
  ) {
    _assertOwnership(command);
    return _client.startMission(command);
  }

  @override
  Future<RawBackendResponse<MissionProgressServerResult>> recordProgress(
    RecordMissionProgressCommand command,
  ) {
    _assertOwnership(command);
    return _client.recordProgress(command);
  }

  @override
  Future<RawBackendResponse<MissionSubmissionServerResult>> submitMission(
    SubmitMissionCommand command,
  ) {
    _assertOwnership(command);
    return _client.submitMission(command);
  }

  @override
  Future<RawBackendResponse<void>> cancelMission(CancelMissionCommand command) {
    _assertOwnership(command);
    return _client.cancelMission(command);
  }
}
