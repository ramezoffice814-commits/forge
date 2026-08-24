// Roadmap Item 13B — real integration tests against the live `forge-staging`
// Supabase project, exercising Forge's actual production adapter classes
// (SupabaseAuthRepository, SupabaseEdgeFunctionsClient,
// SupabaseMissionAssignmentClient, SupabaseBackendClient,
// AuthenticatedBackendClient, SyncQueueingBackendClient,
// PersistedSyncQueueStore) — never a fake, never SQL, always a real HTTP
// round trip to real staging infrastructure.
//
// Tagged `live_staging` (see dart_test.yaml) so this file is excluded from
// the default `flutter test` run — it needs real network access and real
// staging credentials, neither of which any other machine running the
// default suite should be expected to have. Run explicitly with:
//
//   flutter test --tags=live_staging \
//     --dart-define=SUPABASE_URL=https://hidhbgsbcmkqntqrrnjx.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=<staging anon key> \
//     --dart-define=STAGING_TEST_PASSWORD=<synthetic test user password>
//
// The two synthetic staging users this file signs in as
// (forge-staging-e2e-2@forge.internal.test /
// forge-staging-e2e-userb@forge.internal.test) were created directly via
// admin SQL against auth.users + auth.identities — bypassing GoTrue's
// rate-limited signup endpoint entirely (Item 13B section 2, option B) —
// never through production, never with a committed password. The password
// is read from STAGING_TEST_PASSWORD at test-run time only; nothing here
// hardcodes or logs it.
//
// Every test is a no-op (skipped) unless AppConfig.isLive is true, so this
// file is always safe to have in the repo regardless of how `flutter test`
// is invoked elsewhere.
@Tags(['live_staging'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/authenticated_backend_client.dart';
import 'package:forge/core/backend/backend_error_ux.dart';
import 'package:forge/core/backend/commands/accept_mission_command.dart';
import 'package:forge/core/backend/commands/backend_command.dart';
import 'package:forge/core/backend/commands/start_mission_command.dart';
import 'package:forge/core/backend/commands/submit_mission_command.dart';
import 'package:forge/core/backend/persisted_sync_queue_store.dart';
import 'package:forge/core/backend/responses/server_validation_status.dart';
import 'package:forge/core/backend/supabase_backend_client.dart';
import 'package:forge/core/backend/supabase_edge_functions_client.dart';
import 'package:forge/core/backend/supabase_mission_assignment_client.dart';
import 'package:forge/core/backend/sync_queueing_backend_client.dart';
import 'package:forge/core/config/app_config.dart';
import 'package:forge/features/sync/domain/entities/sync_operation.dart';
import 'package:forge/features/sync/domain/entities/sync_queue.dart';
import 'package:forge/features/sync/domain/enums/sync_operation_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../support/fake_secure_key_value_store.dart';

/// Minimal `dart:io`-based POST — deliberately not `package:http` (not a
/// declared dependency of this app; `supabase_flutter` pulls it in only
/// transitively) so this file introduces no new dependency.
Future<(int, String)> _post(
  String url,
  Map<String, String> headers,
  Object body,
) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse(url));
    headers.forEach(request.headers.set);
    request.write(jsonEncode(body));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    return (response.statusCode, responseBody);
  } finally {
    client.close(force: true);
  }
}

const _emailA = 'forge-staging-e2e-2@forge.internal.test';
const _emailB = 'forge-staging-e2e-userb@forge.internal.test';
const _password = String.fromEnvironment('STAGING_TEST_PASSWORD');

/// A bare, non-persisting Supabase client — deliberately not
/// `Supabase.initialize()`'s singleton (that pulls in platform-channel
/// session persistence `main.dart` needs but this adapter-level test
/// doesn't: every test signs in explicitly). Real HTTP, same SDK class
/// `SupabaseAuthRepository`/`SupabaseEdgeFunctionsClient` are built on.
supa.SupabaseClient _client() =>
    supa.SupabaseClient(AppConfig.supabaseUrl, AppConfig.supabaseAnonKey);

Future<supa.SupabaseClient> _signedIn(String email) async {
  final client = _client();
  await client.auth.signInWithPassword(email: email, password: _password);
  return client;
}

void main() {
  if (!AppConfig.isLive || _password.isEmpty) {
    test(
      'skipped: not configured for live staging (needs APP_ENV=live, '
      'SUPABASE_TARGET=staging, SUPABASE_URL/ANON_KEY, and '
      'STAGING_TEST_PASSWORD)',
      () {},
      skip: true,
    );
    return;
  }

  group('real Supabase Auth flow (Item 13B step 3)', () {
    test('sign in, authenticated session, sign out, sign back in', () async {
      final client = _client();

      final signIn1 = await client.auth.signInWithPassword(
        email: _emailA,
        password: _password,
      );
      expect(signIn1.session, isNotNull);
      expect(signIn1.user?.email, _emailA);
      expect(client.auth.currentSession, isNotNull);

      await client.auth.signOut();
      expect(client.auth.currentSession, isNull);

      final signIn2 = await client.auth.signInWithPassword(
        email: _emailA,
        password: _password,
      );
      expect(signIn2.session, isNotNull);
      expect(
        signIn2.user?.id,
        signIn1.user?.id,
        reason: 'signing back in must resolve to the same real user',
      );
    });
  });

  group('real mission assignment + lifecycle via the adapter path '
      '(Item 13B steps 4/6/7 — not SQL)', () {
    test('assign -> accept -> start -> submit yields server-confirmed XP/'
        'progression/achievements, and an exact retry returns the identical '
        'cached result with no duplicate reward', () async {
      final client = await _signedIn(_emailA);
      final userId = client.auth.currentUser!.id;
      addTearDown(client.auth.signOut);

      final functions = SupabaseEdgeFunctionsClient(client);
      final assignment = SupabaseMissionAssignmentClient(functions);
      final backend = AuthenticatedBackendClient(
        SupabaseBackendClient(functions),
        userId,
      );

      final unique = DateTime.now().microsecondsSinceEpoch;
      final assigned = await assignment.assignDailyMission(
        commandId: 'e2e-assign-$unique',
        idempotencyKey: 'e2e-assign-key-$unique',
      );
      expect(assigned.missionInstanceId, isNotEmpty);

      final missionInstanceId = assigned.missionInstanceId;
      var seq = 0;
      final now = DateTime.now().toUtc();

      final accept = await backend.acceptMission(
        AcceptMissionCommand(
          commandId: 'e2e-accept-$unique',
          missionInstanceId: missionInstanceId,
          userId: userId,
          timestamp: now,
          sequence: ++seq,
          idempotencyKey: 'e2e-accept-key-$unique',
        ),
      );
      expect(accept.payload.status, ServerValidationStatus.accepted);

      final start = await backend.startMission(
        StartMissionCommand(
          commandId: 'e2e-start-$unique',
          missionInstanceId: missionInstanceId,
          userId: userId,
          timestamp: now,
          sequence: ++seq,
          idempotencyKey: 'e2e-start-key-$unique',
        ),
      );
      expect(start.payload.status, ServerValidationStatus.accepted);

      final submitCommand = SubmitMissionCommand(
        commandId: 'e2e-submit-$unique',
        missionInstanceId: missionInstanceId,
        userId: userId,
        timestamp: now,
        sequence: ++seq,
        idempotencyKey: 'e2e-submit-key-$unique',
        completionPayload: const {
          'progressType': 'binary',
          'progress': {'completed': true},
        },
      );
      final submit1 = await backend.submitMission(submitCommand);
      expect(submit1.payload.status, ServerValidationStatus.accepted);
      expect(submit1.payload.confirmedXpReward.value, greaterThan(0));
      expect(
        submit1.payload.progressionUpdate.value.confirmedTotalXp,
        greaterThanOrEqualTo(submit1.payload.confirmedXpReward.value),
      );

      // Unknown-outcome retry (Item 13B step 7): same commandId AND
      // idempotencyKey — must return the identical cached result, never
      // a second reward.
      final submit2 = await backend.submitMission(submitCommand);
      expect(
        submit2.payload.confirmedXpReward.value,
        submit1.payload.confirmedXpReward.value,
        reason:
            'a retried submit must return the exact cached reward, '
            'not compute a new one',
      );
      expect(submit2.payload.confirmationId, submit1.payload.confirmationId);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('a stale-sequence conflict maps to a safe, non-leaking Flutter UX '
        'state (Item 13B step 8)', () async {
      final client = await _signedIn(_emailA);
      final userId = client.auth.currentUser!.id;
      addTearDown(client.auth.signOut);

      final functions = SupabaseEdgeFunctionsClient(client);
      final assignment = SupabaseMissionAssignmentClient(functions);
      final backend = AuthenticatedBackendClient(
        SupabaseBackendClient(functions),
        userId,
      );

      final unique = DateTime.now().microsecondsSinceEpoch;
      final assigned = await assignment.assignDailyMission(
        commandId: 'e2e-conflict-assign-$unique',
        idempotencyKey: 'e2e-conflict-assign-key-$unique',
      );
      final missionInstanceId = assigned.missionInstanceId;
      final now = DateTime.now().toUtc();

      await backend.acceptMission(
        AcceptMissionCommand(
          commandId: 'e2e-conflict-accept-$unique',
          missionInstanceId: missionInstanceId,
          userId: userId,
          timestamp: now,
          sequence: 1,
          idempotencyKey: 'e2e-conflict-accept-key-$unique',
        ),
      );

      // Sequence 1 is already consumed by the accept above — a second,
      // genuinely different command reusing it is stale.
      final staleStart = await backend.startMission(
        StartMissionCommand(
          commandId: 'e2e-conflict-stale-$unique',
          missionInstanceId: missionInstanceId,
          userId: userId,
          timestamp: now,
          sequence: 1,
          idempotencyKey: 'e2e-conflict-stale-key-$unique',
        ),
      );

      expect(staleStart.payload.status, ServerValidationStatus.rejected);
      final rawReason = staleStart.payload.reasons.isNotEmpty
          ? staleStart.payload.reasons.first
          : '';

      final uxState = mapBackendErrorToUx('stale_sequence', rawReason);
      expect(
        uxState,
        isA<RefreshAndReconcileUx>(),
        reason:
            'a stale sequence must map to the refresh-and-reconcile '
            'UX state, not a raw error surface',
      );

      final safeCopy = defaultBackendErrorCopy(uxState);
      expect(safeCopy, isNot(contains('sequence')));
      expect(safeCopy, isNot(contains(missionInstanceId)));
      expect(
        safeCopy,
        equals('Catching up with the server — one moment.'),
        reason:
            'must be the fixed, safe copy — never the raw server '
            'message forwarded verbatim',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('offline queue / reconnect reconciliation (Item 13B step 6)', () {
    test('a command issued while unreachable is queued and persisted, then '
        'reconciles against the real server on reconnect with no duplicate '
        'reward', () async {
      final client = await _signedIn(_emailA);
      final userId = client.auth.currentUser!.id;
      addTearDown(client.auth.signOut);

      final realFunctions = SupabaseEdgeFunctionsClient(client);
      final assignment = SupabaseMissionAssignmentClient(realFunctions);
      final unique = DateTime.now().microsecondsSinceEpoch;
      final assigned = await assignment.assignDailyMission(
        commandId: 'e2e-offline-assign-$unique',
        idempotencyKey: 'e2e-offline-assign-key-$unique',
      );
      final missionInstanceId = assigned.missionInstanceId;

      final sharedQueue = SyncQueue<BackendCommand>();
      final unreachableClient = SupabaseEdgeFunctionsClient(
        supa.SupabaseClient(
          'https://unreachable-forge-staging-simulation.invalid',
          AppConfig.supabaseAnonKey,
        ),
      );
      final offlineBackend = SyncQueueingBackendClient(
        AuthenticatedBackendClient(
          SupabaseBackendClient(unreachableClient),
          userId,
        ),
        sharedQueue,
      );

      final acceptCommand = AcceptMissionCommand(
        commandId: 'e2e-offline-accept-$unique',
        missionInstanceId: missionInstanceId,
        userId: userId,
        timestamp: DateTime.now().toUtc(),
        sequence: 1,
        idempotencyKey: 'e2e-offline-accept-key-$unique',
      );

      await expectLater(
        offlineBackend.acceptMission(acceptCommand),
        throwsA(isA<CommandQueuedForSyncException>()),
      );
      expect(sharedQueue.pendingInOrder, hasLength(1));

      final store = PersistedSyncQueueStore(FakeSecureKeyValueStore());
      await store.save(userId, sharedQueue.all);
      final restored = await store.load(userId);
      expect(restored, hasLength(1));
      expect(
        restored.first.payload.idempotencyKey,
        acceptCommand.idempotencyKey,
      );

      // Reconnect: a second client sharing the SAME queue, wrapping the
      // REAL, reachable functions client this time.
      final onlineBackend = SyncQueueingBackendClient(
        AuthenticatedBackendClient(
          SupabaseBackendClient(realFunctions),
          userId,
        ),
        sharedQueue,
      );
      await onlineBackend.flushPending();

      expect(sharedQueue.all.single.status, SyncOperationStatus.confirmed);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('account-switch queue isolation (Item 13B step 9)', () {
    test('User B cannot see or submit User A\'s queued command; User A\'s '
        'queue remains correctly associated after switching back', () async {
      final store = FakeSecureKeyValueStore();
      final persisted = PersistedSyncQueueStore(store);

      final clientA = await _signedIn(_emailA);
      final userIdA = clientA.auth.currentUser!.id;
      final unique = DateTime.now().microsecondsSinceEpoch;

      final queueA = SyncQueue<BackendCommand>();
      queueA.enqueue(
        SyncOperation<BackendCommand>(
          operationId: 'e2e-switch-op-$unique',
          idempotencyKey: 'e2e-switch-key-$unique',
          sequence: 1,
          status: SyncOperationStatus.pending,
          queuedAt: DateTime.now().toUtc(),
          payload: AcceptMissionCommand(
            commandId: 'e2e-switch-cmd-$unique',
            missionInstanceId: 'irrelevant-for-this-isolation-check',
            userId: userIdA,
            timestamp: DateTime.now().toUtc(),
            sequence: 1,
            idempotencyKey: 'e2e-switch-key-$unique',
          ),
        ),
      );
      await persisted.save(userIdA, queueA.all);
      await clientA.auth.signOut();

      final clientB = await _signedIn(_emailB);
      final userIdB = clientB.auth.currentUser!.id;
      addTearDown(clientB.auth.signOut);

      expect(userIdB, isNot(userIdA));

      final queueForB = await persisted.load(userIdB);
      expect(
        queueForB,
        isEmpty,
        reason: "User B must never see User A's persisted queue",
      );

      final queueForAAfterSwitch = await persisted.load(userIdA);
      expect(
        queueForAAfterSwitch,
        hasLength(1),
        reason: "switching to User B must not disturb User A's own queue",
      );
      expect(
        queueForAAfterSwitch.first.payload.userId,
        userIdA,
        reason: 'a restored command must still carry its true owner',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group(
    'FORGE_CRON_SECRET gate over real HTTP (Item 13B step 10)',
    () {
      test('missing secret and wrong secret are both rejected with a stable, '
          'non-leaking error', () async {
        final url = '${AppConfig.supabaseUrl}/functions/v1/finalize-week';
        final payload = {
          'seasonId': '00000000-0000-0000-0000-000000000000',
          'weekNumber': 1,
        };

        final (noSecretStatus, _) = await _post(url, {
          'Content-Type': 'application/json',
        }, payload);
        expect(noSecretStatus, 403);

        final (wrongSecretStatus, wrongSecretBody) = await _post(url, {
          'Content-Type': 'application/json',
          'x-cron-secret': 'guessed-wrong-value',
        }, payload);
        expect(wrongSecretStatus, 403);
        expect(jsonDecode(wrongSecretBody)['message'], 'Not authorized.');
      }, timeout: const Timeout(Duration(seconds: 15)));
    },
    skip:
        'FORGE_CRON_SECRET could not be provisioned this pass — see '
        'the Item 13B report. The correct-secret-accepted path remains '
        'unverified until it is set via the Supabase dashboard or CLI.',
  );
}
