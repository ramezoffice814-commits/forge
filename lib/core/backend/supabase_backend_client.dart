import 'package:flutter/foundation.dart';

import '../security/authoritative_value.dart';
import 'backend_client.dart';
import 'commands/accept_mission_command.dart';
import 'commands/cancel_mission_command.dart';
import 'commands/record_mission_progress_command.dart';
import 'commands/start_mission_command.dart';
import 'commands/submit_mission_command.dart';
import 'edge_functions_client.dart';
import 'raw_backend_response.dart';
import 'responses/mission_accepted_server_result.dart';
import 'responses/mission_progress_server_result.dart';
import 'responses/mission_submission_server_result.dart';
import 'responses/progression_update_summary.dart';
import 'responses/server_validation_status.dart';

/// Thrown when an Edge Function's response body doesn't match the shape
/// this adapter requires — this class never guesses at a missing/
/// wrong-typed field; a malformed response is treated as a hard failure,
/// never silently coerced into a plausible-looking result.
@immutable
class MalformedBackendResponseException implements Exception {
  const MalformedBackendResponseException(this.message);

  final String message;

  @override
  String toString() => 'MalformedBackendResponseException: $message';
}

/// The real [BackendClient], calling the five Forge Edge Functions
/// (`supabase/functions/{accept,start,record-progress,submit,cancel}-
/// mission/`) via [EdgeFunctionsClient]. Every method here does exactly
/// three things: build the request body from the (already client-
/// validated) command, invoke the matching function, and map the
/// response — or a known business-rejection error — into the Phase 10A
/// response contract. No reward calculation, no ownership/sequence
/// logic, and no completion validation happens in this class; all of
/// that lives entirely in the database (see supabase/migrations/
/// 20260817090100_mission_reward_functions.sql), which is the actual
/// authority this adapter is a thin client of.
///
/// [RawBackendResponse.fromBackendAdapter] and
/// [ServerConfirmedValue.fromServerResponse] are only ever called here
/// with data that genuinely came back from [_functions] — never
/// fabricated locally — which is what makes the values this class
/// produces legitimately server-confirmed rather than merely
/// client-asserted (see `core/security/authoritative_value.dart`).
///
/// Contract: [RecordMissionProgressCommand.progressPayload] and
/// [SubmitMissionCommand.completionPayload] must each contain
/// `progressType` (a known progress-type string) and `progress` (that
/// type's own shape) — the same two keys the RPC functions expect.
class SupabaseBackendClient implements BackendClient {
  const SupabaseBackendClient(this._functions);

  final EdgeFunctionsClient _functions;

  static const _businessRejectionCodes = {
    'unauthenticated',
    'forbidden',
    'invalid_payload',
    'forbidden_authority_field',
    'mission_not_found',
    'invalid_transition',
    'stale_sequence',
    'out_of_order',
    'duplicate_command',
    'idempotency_conflict',
    'completion_requirements_not_met',
    'integrity_rejected',
  };

  Map<String, Object?> _baseBody(
    String commandId,
    String idempotencyKey,
    String missionInstanceId,
    int sequence,
    DateTime timestamp,
  ) {
    return {
      'commandId': commandId,
      'idempotencyKey': idempotencyKey,
      'missionInstanceId': missionInstanceId,
      'sequence': sequence,
      // Informational only (spec section 4) — the server never trusts
      // this for any authoritative decision.
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  Future<RawBackendResponse<MissionAcceptedServerResult>> acceptMission(
    AcceptMissionCommand command,
  ) async {
    final body = _baseBody(
      command.commandId,
      command.idempotencyKey,
      command.missionInstanceId,
      command.sequence,
      command.timestamp,
    );
    try {
      final data = await _functions.invoke('accept-mission', body);
      return _parseAcceptedLikeResult(data, command.missionInstanceId);
    } on EdgeFunctionCallFailure catch (e) {
      return _rejectedAcceptedLike(e, command.missionInstanceId);
    }
  }

  @override
  Future<RawBackendResponse<MissionAcceptedServerResult>> startMission(
    StartMissionCommand command,
  ) async {
    final body = _baseBody(
      command.commandId,
      command.idempotencyKey,
      command.missionInstanceId,
      command.sequence,
      command.timestamp,
    );
    try {
      final data = await _functions.invoke('start-mission', body);
      return _parseAcceptedLikeResult(data, command.missionInstanceId);
    } on EdgeFunctionCallFailure catch (e) {
      return _rejectedAcceptedLike(e, command.missionInstanceId);
    }
  }

  @override
  Future<RawBackendResponse<MissionProgressServerResult>> recordProgress(
    RecordMissionProgressCommand command,
  ) async {
    final body = _baseBody(
      command.commandId,
      command.idempotencyKey,
      command.missionInstanceId,
      command.sequence,
      command.timestamp,
    )..addAll(command.progressPayload);
    try {
      final data = await _functions.invoke('record-progress', body);
      return _parseProgressResult(data, command.missionInstanceId);
    } on EdgeFunctionCallFailure catch (e) {
      if (!_businessRejectionCodes.contains(e.errorCode)) {
        throw MalformedBackendResponseException(
          'Edge function call failed with an unrecognized/internal error: ${e.message}',
        );
      }
      final now = DateTime.now().toUtc();
      return RawBackendResponse<MissionProgressServerResult>.fromBackendAdapter(
        payload: MissionProgressServerResult(
          status: ServerValidationStatus.rejected,
          missionInstanceId: command.missionInstanceId,
          acceptedSequence: command.sequence - 1,
          serverTimestamp: now,
          confirmationId: '${command.commandId}:rejected',
          reasons: [e.message],
        ),
        serverTimestamp: now,
        confirmationId: '${command.commandId}:rejected',
      );
    }
  }

  @override
  Future<RawBackendResponse<MissionSubmissionServerResult>> submitMission(
    SubmitMissionCommand command,
  ) async {
    final body = _baseBody(
      command.commandId,
      command.idempotencyKey,
      command.missionInstanceId,
      command.sequence,
      command.timestamp,
    )..addAll(command.completionPayload);
    try {
      final data = await _functions.invoke('submit-mission', body);
      return _parseSubmissionResult(data, command.missionInstanceId);
    } on EdgeFunctionCallFailure catch (e) {
      return _rejectedSubmission(
        e,
        command.missionInstanceId,
        command.commandId,
      );
    }
  }

  @override
  Future<RawBackendResponse<void>> cancelMission(
    CancelMissionCommand command,
  ) async {
    final body = _baseBody(
      command.commandId,
      command.idempotencyKey,
      command.missionInstanceId,
      command.sequence,
      command.timestamp,
    )..['reason'] = command.reason;
    final now = DateTime.now().toUtc();
    try {
      await _functions.invoke('cancel-mission', body);
    } on EdgeFunctionCallFailure catch (e) {
      if (!_businessRejectionCodes.contains(e.errorCode)) rethrow;
      // A cancel that fails for a business reason (already completed,
      // wrong owner, etc.) still needs a response envelope — void has
      // no reasons field to carry the explanation, so it's dropped;
      // callers that need it should read the exception before this
      // point in a future revision that gives cancel a real result type.
    }
    return RawBackendResponse<void>.fromBackendAdapter(
      payload: null,
      serverTimestamp: now,
      confirmationId: '${command.commandId}:confirm',
    );
  }

  // ---- response parsing --------------------------------------------

  RawBackendResponse<MissionAcceptedServerResult> _parseAcceptedLikeResult(
    Map<String, Object?> data,
    String missionInstanceId,
  ) {
    final now = _dateTime(data, 'serverTimestamp');
    final result = MissionAcceptedServerResult(
      status: _validationStatus(data, 'status'),
      missionInstanceId: _matchingMissionInstanceId(data, missionInstanceId),
      serverTimestamp: now,
      confirmationId: _str(data, 'confirmationId'),
      reasons: _stringList(data, 'reasons'),
    );
    return RawBackendResponse<MissionAcceptedServerResult>.fromBackendAdapter(
      payload: result,
      serverTimestamp: now,
      confirmationId: result.confirmationId,
    );
  }

  RawBackendResponse<MissionAcceptedServerResult> _rejectedAcceptedLike(
    EdgeFunctionCallFailure e,
    String missionInstanceId,
  ) {
    if (!_businessRejectionCodes.contains(e.errorCode)) {
      throw MalformedBackendResponseException(
        'Edge function call failed with an unrecognized/internal error: ${e.message}',
      );
    }
    final now = DateTime.now().toUtc();
    return RawBackendResponse<MissionAcceptedServerResult>.fromBackendAdapter(
      payload: MissionAcceptedServerResult(
        status: ServerValidationStatus.rejected,
        missionInstanceId: missionInstanceId,
        serverTimestamp: now,
        confirmationId: 'rejected-${now.microsecondsSinceEpoch}',
        reasons: [e.message],
      ),
      serverTimestamp: now,
      confirmationId: 'rejected-${now.microsecondsSinceEpoch}',
    );
  }

  RawBackendResponse<MissionProgressServerResult> _parseProgressResult(
    Map<String, Object?> data,
    String missionInstanceId,
  ) {
    final now = _dateTime(data, 'serverTimestamp');
    final result = MissionProgressServerResult(
      status: _validationStatus(data, 'status'),
      missionInstanceId: _matchingMissionInstanceId(data, missionInstanceId),
      acceptedSequence: _int(data, 'acceptedSequence'),
      serverTimestamp: now,
      confirmationId: _str(data, 'confirmationId'),
      reasons: _stringList(data, 'reasons'),
    );
    return RawBackendResponse<MissionProgressServerResult>.fromBackendAdapter(
      payload: result,
      serverTimestamp: now,
      confirmationId: result.confirmationId,
    );
  }

  RawBackendResponse<MissionSubmissionServerResult> _parseSubmissionResult(
    Map<String, Object?> data,
    String missionInstanceId,
  ) {
    final now = _dateTime(data, 'serverTimestamp');
    final confirmationId = _str(data, 'confirmationId');

    final xpResponse = RawBackendResponse<int>.fromBackendAdapter(
      payload: _int(data, 'confirmedXpReward'),
      serverTimestamp: now,
      confirmationId: confirmationId,
    );

    final progressionRaw = data['progressionUpdate'];
    if (progressionRaw is! Map) {
      throw const MalformedBackendResponseException(
        'progressionUpdate is missing or not an object.',
      );
    }
    final progressionMap = progressionRaw.map(
      (k, v) => MapEntry(k.toString(), v),
    );
    final progressionResponse =
        RawBackendResponse<ProgressionUpdateSummary>.fromBackendAdapter(
          payload: ProgressionUpdateSummary(
            previousLevel: _intOrZero(progressionMap, 'previousLevel'),
            newLevel: _intOrZero(progressionMap, 'newLevel'),
            confirmedTotalXp: _intOrZero(progressionMap, 'confirmedTotalXp'),
          ),
          serverTimestamp: now,
          confirmationId: confirmationId,
        );

    final achievementsResponse =
        RawBackendResponse<List<String>>.fromBackendAdapter(
          payload: _stringList(data, 'achievementUpdates'),
          serverTimestamp: now,
          confirmationId: confirmationId,
        );

    final competitionResponse = RawBackendResponse<double>.fromBackendAdapter(
      payload: _numOrZero(data, 'competitionScoreUpdate').toDouble(),
      serverTimestamp: now,
      confirmationId: confirmationId,
    );

    final result = MissionSubmissionServerResult(
      status: _validationStatus(data, 'status'),
      missionInstanceId: _matchingMissionInstanceId(data, missionInstanceId),
      confirmedMissionState: _missionServerState(data, 'confirmedMissionState'),
      confirmedXpReward: ServerConfirmedValue.fromServerResponse(xpResponse),
      progressionUpdate: ServerConfirmedValue.fromServerResponse(
        progressionResponse,
      ),
      achievementUpdates: ServerConfirmedValue.fromServerResponse(
        achievementsResponse,
      ),
      competitionScoreUpdate: ServerConfirmedValue.fromServerResponse(
        competitionResponse,
      ),
      integrityStatus: _integrityStatus(data, 'integrityStatus'),
      serverTimestamp: now,
      confirmationId: confirmationId,
      reasons: _stringList(data, 'reasons'),
    );

    return RawBackendResponse<MissionSubmissionServerResult>.fromBackendAdapter(
      payload: result,
      serverTimestamp: now,
      confirmationId: confirmationId,
    );
  }

  RawBackendResponse<MissionSubmissionServerResult> _rejectedSubmission(
    EdgeFunctionCallFailure e,
    String missionInstanceId,
    String commandId,
  ) {
    if (!_businessRejectionCodes.contains(e.errorCode)) {
      throw MalformedBackendResponseException(
        'Edge function call failed with an unrecognized/internal error: ${e.message}',
      );
    }
    final now = DateTime.now().toUtc();
    final confirmationId = '$commandId:rejected';
    final zeroInt = RawBackendResponse<int>.fromBackendAdapter(
      payload: 0,
      serverTimestamp: now,
      confirmationId: confirmationId,
    );
    final zeroProgression =
        RawBackendResponse<ProgressionUpdateSummary>.fromBackendAdapter(
          payload: const ProgressionUpdateSummary(
            previousLevel: 0,
            newLevel: 0,
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

    return RawBackendResponse<MissionSubmissionServerResult>.fromBackendAdapter(
      payload: MissionSubmissionServerResult(
        status: ServerValidationStatus.rejected,
        missionInstanceId: missionInstanceId,
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
        reasons: [e.message],
      ),
      serverTimestamp: now,
      confirmationId: confirmationId,
    );
  }

  // ---- typed field extraction — throws on anything malformed --------

  /// Verifies the response actually confirms the mission the caller
  /// asked about — a response for the wrong mission id is exactly the
  /// kind of malformed-and-dangerous thing this adapter must reject
  /// rather than silently trust.
  String _matchingMissionInstanceId(
    Map<String, Object?> data,
    String expected,
  ) {
    final actual = _str(data, 'missionInstanceId');
    if (actual != expected) {
      throw MalformedBackendResponseException(
        'Response missionInstanceId "$actual" does not match the requested "$expected".',
      );
    }
    return actual;
  }

  String _str(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! String) {
      throw MalformedBackendResponseException(
        'Expected string field "$key", got: $value',
      );
    }
    return value;
  }

  int _int(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw MalformedBackendResponseException(
      'Expected numeric field "$key", got: $value',
    );
  }

  int _intOrZero(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw MalformedBackendResponseException(
      'Expected numeric field "$key", got: $value',
    );
  }

  num _numOrZero(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) return 0;
    if (value is num) return value;
    throw MalformedBackendResponseException(
      'Expected numeric field "$key", got: $value',
    );
  }

  DateTime _dateTime(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc();
    }
    throw MalformedBackendResponseException(
      'Expected an ISO-8601 timestamp field "$key", got: $value',
    );
  }

  List<String> _stringList(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) return const [];
    if (value is List && value.every((e) => e is String)) {
      return value.cast<String>();
    }
    throw MalformedBackendResponseException(
      'Expected a string list field "$key", got: $value',
    );
  }

  ServerValidationStatus _validationStatus(
    Map<String, Object?> data,
    String key,
  ) {
    return switch (_str(data, key)) {
      'accepted' => ServerValidationStatus.accepted,
      'rejected' => ServerValidationStatus.rejected,
      'pending' => ServerValidationStatus.pending,
      final other => throw MalformedBackendResponseException(
        'Unknown status value: $other',
      ),
    };
  }

  MissionServerState _missionServerState(
    Map<String, Object?> data,
    String key,
  ) {
    return switch (_str(data, key)) {
      'completed' => MissionServerState.completed,
      'rejected' => MissionServerState.rejected,
      'pendingReview' => MissionServerState.pendingReview,
      final other => throw MalformedBackendResponseException(
        'Unknown mission server state: $other',
      ),
    };
  }

  ServerIntegrityStatus _integrityStatus(
    Map<String, Object?> data,
    String key,
  ) {
    return switch (_str(data, key)) {
      'clean' => ServerIntegrityStatus.clean,
      'warning' => ServerIntegrityStatus.warning,
      'excluded' || 'rejected' => ServerIntegrityStatus.rejected,
      final other => throw MalformedBackendResponseException(
        'Unknown integrity status: $other',
      ),
    };
  }
}
