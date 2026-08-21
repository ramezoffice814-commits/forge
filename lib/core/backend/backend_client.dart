import 'commands/accept_mission_command.dart';
import 'commands/cancel_mission_command.dart';
import 'commands/record_mission_progress_command.dart';
import 'commands/start_mission_command.dart';
import 'commands/submit_mission_command.dart';
import 'raw_backend_response.dart';
import 'responses/mission_accepted_server_result.dart';
import 'responses/mission_progress_server_result.dart';
import 'responses/mission_submission_server_result.dart';

/// The one seam between the app and "a backend" — never Supabase (or any
/// other SDK) directly. Domain/presentation code depends on this
/// interface only; concrete adapters (mock now, Supabase later — see
/// `supabase_backend_client.dart`) live entirely behind it.
///
/// Every method returns a [RawBackendResponse] wrapping the actual result
/// — that envelope, not the result type itself, is what proves the value
/// is genuinely server-sourced.
abstract class BackendClient {
  Future<RawBackendResponse<MissionAcceptedServerResult>> acceptMission(
    AcceptMissionCommand command,
  );

  Future<RawBackendResponse<MissionAcceptedServerResult>> startMission(
    StartMissionCommand command,
  );

  Future<RawBackendResponse<MissionProgressServerResult>> recordProgress(
    RecordMissionProgressCommand command,
  );

  Future<RawBackendResponse<MissionSubmissionServerResult>> submitMission(
    SubmitMissionCommand command,
  );

  Future<RawBackendResponse<void>> cancelMission(CancelMissionCommand command);
}
