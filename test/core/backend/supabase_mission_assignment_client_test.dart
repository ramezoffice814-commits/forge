import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/edge_functions_client.dart';
import 'package:forge/core/backend/supabase_backend_client.dart';
import 'package:forge/core/backend/supabase_mission_assignment_client.dart';

class FakeEdgeFunctionsClient implements EdgeFunctionsClient {
  FakeEdgeFunctionsClient(this._respond);

  final Map<String, Object?> Function(
    String functionName,
    Map<String, Object?> body,
  )
  _respond;
  final List<(String, Map<String, Object?>)> calls = [];

  @override
  Future<Map<String, Object?>> invoke(
    String functionName,
    Map<String, Object?> body,
  ) async {
    calls.add((functionName, body));
    return _respond(functionName, body);
  }
}

void main() {
  test(
    'calls assign-daily-mission and parses a well-formed response',
    () async {
      final fake = FakeEdgeFunctionsClient((fn, body) {
        expect(fn, 'assign-daily-mission');
        expect(body['commandId'], 'cmd-1');
        return {
          'status': 'accepted',
          'missionInstanceId': 'mission-1',
          'missionDefinitionId': 'def-1',
          'assignedDate': '2026-08-20',
          'serverTimestamp': '2026-08-20T12:00:00.000Z',
          'confirmationId': 'confirm-1',
          'reasons': <String>[],
        };
      });
      final client = SupabaseMissionAssignmentClient(fake);

      final result = await client.assignDailyMission(
        commandId: 'cmd-1',
        idempotencyKey: 'key-1',
      );

      expect(result.missionInstanceId, 'mission-1');
      expect(result.missionDefinitionId, 'def-1');
      expect(result.confirmationId, 'confirm-1');
    },
  );

  test('forwards an optional requested mission definition id', () async {
    final fake = FakeEdgeFunctionsClient((fn, body) {
      expect(body['requestedMissionDefinitionId'], 'def-42');
      return {
        'status': 'accepted',
        'missionInstanceId': 'mission-1',
        'missionDefinitionId': 'def-42',
        'assignedDate': '2026-08-20',
        'serverTimestamp': '2026-08-20T12:00:00.000Z',
        'confirmationId': 'confirm-1',
      };
    });
    final client = SupabaseMissionAssignmentClient(fake);

    await client.assignDailyMission(
      commandId: 'cmd-1',
      idempotencyKey: 'key-1',
      requestedMissionDefinitionId: 'def-42',
    );

    expect(fake.calls.single.$1, 'assign-daily-mission');
  });

  test(
    'throws MalformedBackendResponseException when a required field is missing',
    () async {
      final fake = FakeEdgeFunctionsClient((fn, body) {
        return {
          'status': 'accepted',
          'missionInstanceId': 'mission-1',
          // missionDefinitionId deliberately omitted.
          'assignedDate': '2026-08-20',
          'serverTimestamp': '2026-08-20T12:00:00.000Z',
          'confirmationId': 'confirm-1',
        };
      });
      final client = SupabaseMissionAssignmentClient(fake);

      await expectLater(
        client.assignDailyMission(commandId: 'cmd-1', idempotencyKey: 'key-1'),
        throwsA(isA<MalformedBackendResponseException>()),
      );
    },
  );

  test(
    'throws MalformedBackendResponseException for an unparsable date',
    () async {
      final fake = FakeEdgeFunctionsClient((fn, body) {
        return {
          'status': 'accepted',
          'missionInstanceId': 'mission-1',
          'missionDefinitionId': 'def-1',
          'assignedDate': 'not-a-date',
          'serverTimestamp': '2026-08-20T12:00:00.000Z',
          'confirmationId': 'confirm-1',
        };
      });
      final client = SupabaseMissionAssignmentClient(fake);

      await expectLater(
        client.assignDailyMission(commandId: 'cmd-1', idempotencyKey: 'key-1'),
        throwsA(isA<MalformedBackendResponseException>()),
      );
    },
  );
}
