import 'backend_client.dart';
import 'commands/accept_mission_command.dart';
import 'commands/cancel_mission_command.dart';
import 'commands/record_mission_progress_command.dart';
import 'commands/start_mission_command.dart';
import 'commands/submit_mission_command.dart';
import 'idempotency_replay_guard.dart';
import 'raw_backend_response.dart';
import 'responses/mission_accepted_server_result.dart';
import 'responses/mission_progress_server_result.dart';
import 'responses/mission_submission_server_result.dart';
import 'responses/progression_update_summary.dart';
import 'responses/server_validation_status.dart';
import 'server_clock.dart';
import '../security/authoritative_value.dart';

/// The only [BackendClient] implementation this phase ships. Reward
/// calculation here is deliberately a fixed, documented placeholder —
/// this class exists to prove the contract shapes and the
/// idempotency/replay/trust-boundary machinery work, not to be a real
/// scoring engine. A future Supabase adapter (see
/// `supabase_backend_client.dart`) implements the same [BackendClient]
/// interface with real server-computed values; nothing above this class
/// needs to change when that happens.
class MockBackendClient implements BackendClient {
  MockBackendClient({this.clock = const SystemClock()});

  final ServerClock clock;
  final IdempotencyReplayGuard _guard = IdempotencyReplayGuard();

  String _confirmationIdFor(String missionInstanceId, int sequence) =>
      '$missionInstanceId-$sequence-confirm';

  @override
  Future<RawBackendResponse<MissionAcceptedServerResult>> acceptMission(
    AcceptMissionCommand command,
  ) async {
    return _handle<MissionAcceptedServerResult>(
      missionInstanceId: command.missionInstanceId,
      idempotencyKey: command.idempotencyKey,
      sequence: command.sequence,
      buildAccepted: (now, confirmationId) => MissionAcceptedServerResult(
        status: ServerValidationStatus.accepted,
        missionInstanceId: command.missionInstanceId,
        serverTimestamp: now,
        confirmationId: confirmationId,
      ),
      buildRejected: (now, confirmationId, reason) =>
          MissionAcceptedServerResult(
            status: ServerValidationStatus.rejected,
            missionInstanceId: command.missionInstanceId,
            serverTimestamp: now,
            confirmationId: confirmationId,
            reasons: [reason],
          ),
    );
  }

  @override
  Future<RawBackendResponse<MissionAcceptedServerResult>> startMission(
    StartMissionCommand command,
  ) async {
    return _handle<MissionAcceptedServerResult>(
      missionInstanceId: command.missionInstanceId,
      idempotencyKey: command.idempotencyKey,
      sequence: command.sequence,
      buildAccepted: (now, confirmationId) => MissionAcceptedServerResult(
        status: ServerValidationStatus.accepted,
        missionInstanceId: command.missionInstanceId,
        serverTimestamp: now,
        confirmationId: confirmationId,
      ),
      buildRejected: (now, confirmationId, reason) =>
          MissionAcceptedServerResult(
            status: ServerValidationStatus.rejected,
            missionInstanceId: command.missionInstanceId,
            serverTimestamp: now,
            confirmationId: confirmationId,
            reasons: [reason],
          ),
    );
  }

  @override
  Future<RawBackendResponse<MissionProgressServerResult>> recordProgress(
    RecordMissionProgressCommand command,
  ) async {
    return _handle<MissionProgressServerResult>(
      missionInstanceId: command.missionInstanceId,
      idempotencyKey: command.idempotencyKey,
      sequence: command.sequence,
      buildAccepted: (now, confirmationId) => MissionProgressServerResult(
        status: ServerValidationStatus.accepted,
        missionInstanceId: command.missionInstanceId,
        acceptedSequence: command.sequence,
        serverTimestamp: now,
        confirmationId: confirmationId,
      ),
      buildRejected: (now, confirmationId, reason) =>
          MissionProgressServerResult(
            status: ServerValidationStatus.rejected,
            missionInstanceId: command.missionInstanceId,
            acceptedSequence: _guard.lastAcceptedSequenceFor(
              command.missionInstanceId,
            ),
            serverTimestamp: now,
            confirmationId: confirmationId,
            reasons: [reason],
          ),
    );
  }

  @override
  Future<RawBackendResponse<MissionSubmissionServerResult>> submitMission(
    SubmitMissionCommand command,
  ) async {
    return _handle<MissionSubmissionServerResult>(
      missionInstanceId: command.missionInstanceId,
      idempotencyKey: command.idempotencyKey,
      sequence: command.sequence,
      buildAccepted: (now, confirmationId) {
        // Fixed, documented placeholder reward — see class doc comment.
        final xpResponse = RawBackendResponse<int>.fromBackendAdapter(
          payload: 20,
          serverTimestamp: now,
          confirmationId: confirmationId,
        );
        final progressionResponse =
            RawBackendResponse<ProgressionUpdateSummary>.fromBackendAdapter(
              payload: const ProgressionUpdateSummary(
                previousLevel: 1,
                newLevel: 1,
                confirmedTotalXp: 20,
              ),
              serverTimestamp: now,
              confirmationId: confirmationId,
            );
        final achievementsResponse =
            RawBackendResponse<List<String>>.fromBackendAdapter(
              payload: const [],
              serverTimestamp: now,
              confirmationId: confirmationId,
            );
        final competitionResponse =
            RawBackendResponse<double>.fromBackendAdapter(
              payload: 10.0,
              serverTimestamp: now,
              confirmationId: confirmationId,
            );

        return MissionSubmissionServerResult(
          status: ServerValidationStatus.accepted,
          missionInstanceId: command.missionInstanceId,
          confirmedMissionState: MissionServerState.completed,
          confirmedXpReward: ServerConfirmedValue.fromServerResponse(
            xpResponse,
          ),
          progressionUpdate: ServerConfirmedValue.fromServerResponse(
            progressionResponse,
          ),
          achievementUpdates: ServerConfirmedValue.fromServerResponse(
            achievementsResponse,
          ),
          competitionScoreUpdate: ServerConfirmedValue.fromServerResponse(
            competitionResponse,
          ),
          integrityStatus: ServerIntegrityStatus.clean,
          serverTimestamp: now,
          confirmationId: confirmationId,
        );
      },
      buildRejected: (now, confirmationId, reason) {
        final zeroInt = RawBackendResponse<int>.fromBackendAdapter(
          payload: 0,
          serverTimestamp: now,
          confirmationId: confirmationId,
        );
        final zeroProgression =
            RawBackendResponse<ProgressionUpdateSummary>.fromBackendAdapter(
              payload: const ProgressionUpdateSummary(
                previousLevel: 1,
                newLevel: 1,
                confirmedTotalXp: 0,
              ),
              serverTimestamp: now,
              confirmationId: confirmationId,
            );
        final zeroAchievements =
            RawBackendResponse<List<String>>.fromBackendAdapter(
              payload: const [],
              serverTimestamp: now,
              confirmationId: confirmationId,
            );
        final zeroCompetition = RawBackendResponse<double>.fromBackendAdapter(
          payload: 0.0,
          serverTimestamp: now,
          confirmationId: confirmationId,
        );

        return MissionSubmissionServerResult(
          status: ServerValidationStatus.rejected,
          missionInstanceId: command.missionInstanceId,
          confirmedMissionState: MissionServerState.rejected,
          confirmedXpReward: ServerConfirmedValue.fromServerResponse(zeroInt),
          progressionUpdate: ServerConfirmedValue.fromServerResponse(
            zeroProgression,
          ),
          achievementUpdates: ServerConfirmedValue.fromServerResponse(
            zeroAchievements,
          ),
          competitionScoreUpdate: ServerConfirmedValue.fromServerResponse(
            zeroCompetition,
          ),
          integrityStatus: ServerIntegrityStatus.rejected,
          serverTimestamp: now,
          confirmationId: confirmationId,
          reasons: [reason],
        );
      },
    );
  }

  @override
  Future<RawBackendResponse<void>> cancelMission(
    CancelMissionCommand command,
  ) async {
    return _handle<void>(
      missionInstanceId: command.missionInstanceId,
      idempotencyKey: command.idempotencyKey,
      sequence: command.sequence,
      buildAccepted: (now, confirmationId) {},
      buildRejected: (now, confirmationId, reason) {},
    );
  }

  Future<RawBackendResponse<T>> _handle<T>({
    required String missionInstanceId,
    required String idempotencyKey,
    required int sequence,
    required T Function(DateTime now, String confirmationId) buildAccepted,
    required T Function(DateTime now, String confirmationId, String reason)
    buildRejected,
  }) async {
    final now = clock.now();
    final confirmationId = _confirmationIdFor(missionInstanceId, sequence);
    final acceptance = _guard.evaluate(
      missionInstanceId: missionInstanceId,
      idempotencyKey: idempotencyKey,
      sequence: sequence,
    );

    switch (acceptance) {
      case CommandAcceptance.duplicateRetry:
        final cached =
            _guard.cachedResultFor(idempotencyKey) as RawBackendResponse<T>;
        return cached;
      case CommandAcceptance.staleSequence:
        return RawBackendResponse<T>.fromBackendAdapter(
          payload: buildRejected(
            now,
            confirmationId,
            'Stale sequence: this command has already been superseded.',
          ),
          serverTimestamp: now,
          confirmationId: confirmationId,
        );
      case CommandAcceptance.outOfOrder:
        return RawBackendResponse<T>.fromBackendAdapter(
          payload: buildRejected(
            now,
            confirmationId,
            'Out-of-order sequence: an earlier command for this mission '
            'has not been received yet.',
          ),
          serverTimestamp: now,
          confirmationId: confirmationId,
        );
      case CommandAcceptance.accepted:
        final response = RawBackendResponse<T>.fromBackendAdapter(
          payload: buildAccepted(now, confirmationId),
          serverTimestamp: now,
          confirmationId: confirmationId,
        );
        _guard.recordAccepted(
          missionInstanceId: missionInstanceId,
          idempotencyKey: idempotencyKey,
          sequence: sequence,
          result: response,
        );
        return response;
    }
  }
}
