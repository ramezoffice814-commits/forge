import 'edge_functions_client.dart';
import 'mission_assignment_client.dart';
import 'supabase_backend_client.dart' show MalformedBackendResponseException;

/// Real implementation — calls `assign-daily-mission` via the same
/// [EdgeFunctionsClient] seam [SupabaseBackendClient] uses, so it's
/// unit-testable offline the same way (a fake [EdgeFunctionsClient], no
/// network) and never depends on the Supabase SDK directly.
class SupabaseMissionAssignmentClient implements MissionAssignmentClient {
  const SupabaseMissionAssignmentClient(this._functions);

  final EdgeFunctionsClient _functions;

  @override
  Future<MissionAssignmentResult> assignDailyMission({
    required String commandId,
    required String idempotencyKey,
    String? requestedMissionDefinitionId,
    String? requestedCategory,
  }) async {
    final data = await _functions.invoke('assign-daily-mission', {
      'commandId': commandId,
      'idempotencyKey': idempotencyKey,
      'requestedMissionDefinitionId': ?requestedMissionDefinitionId,
      'requestedCategory': ?requestedCategory,
    });

    return MissionAssignmentResult(
      missionInstanceId: _str(data, 'missionInstanceId'),
      missionDefinitionId: _str(data, 'missionDefinitionId'),
      assignedDate: _date(data, 'assignedDate'),
      serverTimestamp: _dateTime(data, 'serverTimestamp'),
      confirmationId: _str(data, 'confirmationId'),
      reasons: _stringList(data, 'reasons'),
    );
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

  DateTime _date(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw MalformedBackendResponseException(
      'Expected a date field "$key", got: $value',
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
}
