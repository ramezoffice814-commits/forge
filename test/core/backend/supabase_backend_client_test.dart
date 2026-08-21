import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/commands/cancel_mission_command.dart';
import 'package:forge/core/backend/commands/start_mission_command.dart';
import 'package:forge/core/backend/edge_functions_client.dart';
import 'package:forge/core/backend/supabase_backend_client.dart';
import 'package:forge/core/security/authoritative_value.dart';

import '../../support/backend_test_helpers.dart';

/// No network, no Supabase project — [FakeEdgeFunctionsClient] is the
/// one seam [SupabaseBackendClient] depends on for actually calling a
/// function, so these tests exercise the adapter's real request/
/// response-mapping and trust-boundary logic entirely offline.
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

class ThrowingEdgeFunctionsClient implements EdgeFunctionsClient {
  ThrowingEdgeFunctionsClient(this._failure);

  final EdgeFunctionCallFailure _failure;

  @override
  Future<Map<String, Object?>> invoke(
    String functionName,
    Map<String, Object?> body,
  ) async {
    throw _failure;
  }
}

void main() {
  final now = DateTime.utc(2026, 8, 17, 12);

  group('SupabaseBackendClient.acceptMission', () {
    test('parses a well-formed accepted response', () async {
      final fake = FakeEdgeFunctionsClient((fn, body) {
        expect(fn, 'accept-mission');
        expect(body['missionInstanceId'], testMissionInstanceId);
        return {
          'status': 'accepted',
          'missionInstanceId': testMissionInstanceId,
          'serverTimestamp': now.toIso8601String(),
          'confirmationId': 'confirm-1',
          'reasons': <String>[],
        };
      });
      final client = SupabaseBackendClient(fake);

      final response = await client.acceptMission(
        testAcceptCommand(timestamp: now),
      );

      expect(response.payload.missionInstanceId, testMissionInstanceId);
      expect(response.payload.confirmationId, 'confirm-1');
      expect(response.confirmationId, 'confirm-1');
    });

    test(
      'throws MalformedBackendResponseException when a required field is missing',
      () async {
        final fake = FakeEdgeFunctionsClient((fn, body) {
          return {
            'status': 'accepted',
            'missionInstanceId': testMissionInstanceId,
            // serverTimestamp deliberately omitted.
            'confirmationId': 'confirm-1',
          };
        });
        final client = SupabaseBackendClient(fake);

        await expectLater(
          client.acceptMission(testAcceptCommand(timestamp: now)),
          throwsA(isA<MalformedBackendResponseException>()),
        );
      },
    );

    test(
      'throws MalformedBackendResponseException when missionInstanceId does not match',
      () async {
        final fake = FakeEdgeFunctionsClient((fn, body) {
          return {
            'status': 'accepted',
            'missionInstanceId': 'a-different-mission',
            'serverTimestamp': now.toIso8601String(),
            'confirmationId': 'confirm-1',
          };
        });
        final client = SupabaseBackendClient(fake);

        await expectLater(
          client.acceptMission(testAcceptCommand(timestamp: now)),
          throwsA(isA<MalformedBackendResponseException>()),
        );
      },
    );

    test(
      'maps a business rejection (invalid_transition) to a rejected result, not an exception',
      () async {
        final client = SupabaseBackendClient(
          ThrowingEdgeFunctionsClient(
            const EdgeFunctionCallFailure(
              'Mission cannot be accepted from status "completed".',
              errorCode: 'invalid_transition',
              statusCode: 409,
            ),
          ),
        );

        final response = await client.acceptMission(
          testAcceptCommand(timestamp: now),
        );

        expect(response.payload.status.name, 'rejected');
        expect(response.payload.reasons, isNotEmpty);
      },
    );

    test(
      'rethrows as MalformedBackendResponseException for an unrecognized/internal failure',
      () async {
        final client = SupabaseBackendClient(
          ThrowingEdgeFunctionsClient(
            const EdgeFunctionCallFailure('boom', errorCode: null),
          ),
        );

        await expectLater(
          client.acceptMission(testAcceptCommand(timestamp: now)),
          throwsA(isA<MalformedBackendResponseException>()),
        );
      },
    );
  });

  group('SupabaseBackendClient.startMission', () {
    test('parses a well-formed response', () async {
      final fake = FakeEdgeFunctionsClient((fn, body) {
        expect(fn, 'start-mission');
        return {
          'status': 'accepted',
          'missionInstanceId': testMissionInstanceId,
          'serverTimestamp': now.toIso8601String(),
          'confirmationId': 'confirm-start',
          'reasons': <String>[],
        };
      });
      final client = SupabaseBackendClient(fake);

      final response = await client.startMission(
        StartMissionCommand(
          commandId: 'cmd-start-1',
          missionInstanceId: testMissionInstanceId,
          userId: testBackendUserId,
          timestamp: now,
          sequence: 2,
          idempotencyKey: 'key-start-1',
        ),
      );

      expect(response.payload.confirmationId, 'confirm-start');
    });
  });

  group('SupabaseBackendClient.recordProgress', () {
    test('forwards the progress payload and parses acceptedSequence', () async {
      final fake = FakeEdgeFunctionsClient((fn, body) {
        expect(fn, 'record-progress');
        expect(body['percent'], 50);
        return {
          'status': 'accepted',
          'missionInstanceId': testMissionInstanceId,
          'acceptedSequence': 2,
          'serverTimestamp': now.toIso8601String(),
          'confirmationId': 'confirm-progress',
          'reasons': <String>[],
        };
      });
      final client = SupabaseBackendClient(fake);

      final response = await client.recordProgress(
        testProgressCommand(timestamp: now),
      );

      expect(response.payload.acceptedSequence, 2);
    });
  });

  group('SupabaseBackendClient.submitMission', () {
    test(
      'parses the full nested submission response into server-confirmed values',
      () async {
        final fake = FakeEdgeFunctionsClient((fn, body) {
          expect(fn, 'submit-mission');
          return {
            'status': 'accepted',
            'missionInstanceId': testMissionInstanceId,
            'confirmedMissionState': 'completed',
            'confirmedXpReward': 12,
            'progressionUpdate': {
              'previousLevel': 1,
              'newLevel': 1,
              'confirmedTotalXp': 12,
            },
            'achievementUpdates': ['first-steps'],
            'competitionScoreUpdate': 8.8,
            'integrityStatus': 'clean',
            'serverTimestamp': now.toIso8601String(),
            'confirmationId': 'confirm-submit',
            'reasons': <String>[],
          };
        });
        final client = SupabaseBackendClient(fake);

        final response = await client.submitMission(
          testSubmitCommand(timestamp: now),
        );
        final result = response.payload;

        expect(result.confirmedXpReward, isA<ServerConfirmedValue<int>>());
        expect(result.confirmedXpReward.value, 12);
        expect(result.progressionUpdate.value.newLevel, 1);
        expect(result.progressionUpdate.value.confirmedTotalXp, 12);
        expect(result.achievementUpdates.value, ['first-steps']);
        expect(result.competitionScoreUpdate.value, 8.8);
        expect(result.integrityStatus.name, 'clean');
        expect(result.confirmedXpReward.authority.name, 'serverConfirmed');
      },
    );

    test(
      'a completion_requirements_not_met rejection is a normal rejected result',
      () async {
        final client = SupabaseBackendClient(
          ThrowingEdgeFunctionsClient(
            const EdgeFunctionCallFailure(
              'Progress does not meet the mission\'s completion criteria.',
              errorCode: 'completion_requirements_not_met',
              statusCode: 422,
            ),
          ),
        );

        final response = await client.submitMission(
          testSubmitCommand(timestamp: now),
        );

        expect(response.payload.status.name, 'rejected');
        expect(response.payload.confirmedXpReward.value, 0);
      },
    );

    test(
      'throws MalformedBackendResponseException when progressionUpdate is missing',
      () async {
        final fake = FakeEdgeFunctionsClient((fn, body) {
          return {
            'status': 'accepted',
            'missionInstanceId': testMissionInstanceId,
            'confirmedMissionState': 'completed',
            'confirmedXpReward': 12,
            // progressionUpdate deliberately omitted.
            'achievementUpdates': <String>[],
            'competitionScoreUpdate': 0,
            'integrityStatus': 'clean',
            'serverTimestamp': now.toIso8601String(),
            'confirmationId': 'confirm-submit',
            'reasons': <String>[],
          };
        });
        final client = SupabaseBackendClient(fake);

        await expectLater(
          client.submitMission(testSubmitCommand(timestamp: now)),
          throwsA(isA<MalformedBackendResponseException>()),
        );
      },
    );
  });

  group('SupabaseBackendClient.cancelMission', () {
    test('completes successfully for a well-formed response', () async {
      final fake = FakeEdgeFunctionsClient((fn, body) {
        expect(fn, 'cancel-mission');
        return {
          'status': 'accepted',
          'missionInstanceId': testMissionInstanceId,
          'serverTimestamp': now.toIso8601String(),
          'confirmationId': 'confirm-cancel',
        };
      });
      final client = SupabaseBackendClient(fake);

      final response = await client.cancelMission(
        CancelMissionCommand(
          commandId: 'cmd-cancel-1',
          missionInstanceId: testMissionInstanceId,
          userId: testBackendUserId,
          timestamp: now,
          sequence: 4,
          idempotencyKey: 'key-cancel-1',
        ),
      );

      expect(response.confirmationId, isNotEmpty);
    });

    test('does not throw for a business rejection', () async {
      final client = SupabaseBackendClient(
        ThrowingEdgeFunctionsClient(
          const EdgeFunctionCallFailure(
            'Mission cannot be cancelled from status "completed".',
            errorCode: 'invalid_transition',
            statusCode: 409,
          ),
        ),
      );

      await expectLater(
        client.cancelMission(
          CancelMissionCommand(
            commandId: 'cmd-cancel-2',
            missionInstanceId: testMissionInstanceId,
            userId: testBackendUserId,
            timestamp: now,
            sequence: 4,
            idempotencyKey: 'key-cancel-2',
          ),
        ),
        completes,
      );
    });
  });
}
