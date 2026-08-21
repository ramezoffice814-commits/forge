import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/authenticated_backend_client.dart';
import 'package:forge/core/backend/mock_backend_client.dart';
import 'package:forge/core/backend/responses/server_validation_status.dart';
import 'package:forge/core/backend/server_clock.dart';

import '../../support/backend_test_helpers.dart';

void main() {
  final clock = MockServerClock(DateTime.utc(2026, 8, 10));

  test('a command whose userId matches the authenticated session is '
      'forwarded normally', () async {
    final authenticated = AuthenticatedBackendClient(
      MockBackendClient(clock: clock),
      testBackendUserId,
    );
    final response = await authenticated.acceptMission(
      testAcceptCommand(timestamp: clock.now(), userId: testBackendUserId),
    );
    expect(response.payload.status, ServerValidationStatus.accepted);
  });

  test('a command for a different userId is refused before it ever '
      'reaches the underlying BackendClient', () async {
    final authenticated = AuthenticatedBackendClient(
      MockBackendClient(clock: clock),
      testBackendUserId,
    );
    expect(
      () => authenticated.acceptMission(
        testAcceptCommand(timestamp: clock.now(), userId: 'someone-else'),
      ),
      throwsStateError,
    );
  });
}
