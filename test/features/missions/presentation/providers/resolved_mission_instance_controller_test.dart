// Roadmap Item 13C: the core identity-adoption contracts —
// ResolvedMissionInstanceController must never let a live-mode command
// carry a locally-generated id, must adopt the server's real assignment
// (or a cached one offline), and must never fabricate display facts for
// a server-reconciled-to-a-different-mission scenario.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/backend_mode.dart';
import 'package:forge/core/backend/backend_providers.dart';
import 'package:forge/core/backend/mission_assignment_client.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/features/missions/domain/entities/resolved_mission_instance.dart';
import 'package:forge/features/missions/domain/enums/mission_instance_authority.dart';
import 'package:forge/features/missions/presentation/providers/mission_instance_provider.dart';
import 'package:forge/features/missions/presentation/providers/resolved_mission_instance_controller.dart';

import '../../../../support/fake_secure_key_value_store.dart';

const _userId = 'user-13c';

class _FakeAssignmentClient implements MissionAssignmentClient {
  _FakeAssignmentClient(this._respond);

  final Future<MissionAssignmentResult> Function() _respond;
  int callCount = 0;

  @override
  Future<MissionAssignmentResult> assignDailyMission({
    required String commandId,
    required String idempotencyKey,
    String? requestedMissionDefinitionId,
    String? requestedCategory,
  }) {
    callCount++;
    return _respond();
  }
}

class _ThrowingAssignmentClient implements MissionAssignmentClient {
  int callCount = 0;

  @override
  Future<MissionAssignmentResult> assignDailyMission({
    required String commandId,
    required String idempotencyKey,
    String? requestedMissionDefinitionId,
    String? requestedCategory,
  }) {
    callCount++;
    throw Exception('simulated network failure');
  }
}

Future<ResolvedMissionInstance?> _resolve(ProviderContainer container) async {
  await container
      .read(resolvedMissionInstanceControllerProvider.notifier)
      .ready;
  return container.read(resolvedMissionInstanceProvider);
}

void main() {
  test('mock mode: resolves to the same instance missionInstanceProvider '
      'builds locally, marked localOnly', () async {
    final container = ProviderContainer(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final resolved = await _resolve(container);
    final local = container.read(missionInstanceProvider);

    expect(resolved, isNotNull);
    expect(resolved!.authority, MissionInstanceAuthority.localOnly);
    expect(resolved.instance.instanceId, local!.instanceId);
  });

  test('live mode: adopts the server-assigned missionInstanceId — never the '
      'locally-generated one', () async {
    const serverInstanceId = '11111111-1111-1111-1111-111111111111';
    final client = _FakeAssignmentClient(
      () async => MissionAssignmentResult(
        missionInstanceId: serverInstanceId,
        missionDefinitionId: 'fit-stretch-10',
        assignedDate: DateTime.utc(2026, 1, 1),
        serverTimestamp: DateTime.utc(2026, 1, 1),
        confirmationId: 'conf-1',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
        backendModeProvider.overrideWithValue(BackendMode.liveSupabase),
        currentBackendUserIdProvider.overrideWithValue(_userId),
        missionAssignmentClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    final resolved = await _resolve(container);
    final local = container.read(missionInstanceProvider);

    expect(resolved, isNotNull);
    expect(resolved!.authority, MissionInstanceAuthority.serverConfirmed);
    expect(resolved.instance.instanceId, serverInstanceId);
    expect(
      resolved.instance.instanceId,
      isNot(local!.instanceId),
      reason:
          'the server id must never coincide with (or be replaced by) '
          "the local engine's own deterministic id in live mode",
    );
    expect(client.callCount, 1);
  });

  test('live mode: the resolved instance never regenerates once resolved — '
      'a second read returns the identical id', () async {
    var calls = 0;
    final client = _FakeAssignmentClient(() async {
      calls++;
      return MissionAssignmentResult(
        missionInstanceId: 'stable-server-id',
        missionDefinitionId: 'fit-stretch-10',
        assignedDate: DateTime.utc(2026, 1, 1),
        serverTimestamp: DateTime.utc(2026, 1, 1),
        confirmationId: 'conf-$calls',
      );
    });

    final container = ProviderContainer(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
        backendModeProvider.overrideWithValue(BackendMode.liveSupabase),
        currentBackendUserIdProvider.overrideWithValue(_userId),
        missionAssignmentClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    final first = await _resolve(container);
    final second = container.read(resolvedMissionInstanceProvider);

    expect(second!.instance.instanceId, first!.instance.instanceId);
    expect(
      client.callCount,
      1,
      reason:
          'resolution runs once per controller lifetime, not once '
          'per read',
    );
  });

  test('live mode, server reconciles to a different mission than requested: '
      'uses the real server mission facts, never the locally-requested '
      "one's facts, and flags the reconciliation", () async {
    final client = _FakeAssignmentClient(
      () async => MissionAssignmentResult(
        // The server already had a different mission assigned for
        // today (e.g. from an earlier session) — 'code-review-1' is a
        // different catalog entry than whatever the local engine
        // requested.
        missionInstanceId: 'server-existing-instance',
        missionDefinitionId: 'code-review-1',
        assignedDate: DateTime.utc(2026, 1, 1),
        serverTimestamp: DateTime.utc(2026, 1, 1),
        confirmationId: 'conf-reconciled',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
        backendModeProvider.overrideWithValue(BackendMode.liveSupabase),
        currentBackendUserIdProvider.overrideWithValue(_userId),
        missionAssignmentClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    final resolved = await _resolve(container);

    expect(resolved, isNotNull);
    expect(resolved!.reconciledToDifferentMission, isTrue);
    expect(resolved.authority, MissionInstanceAuthority.serverConfirmed);
    expect(resolved.instance.instanceId, 'server-existing-instance');
    expect(
      resolved.instance.definitionId,
      'code-review-1',
      reason:
          'display facts must come from the catalog entry the '
          'server actually assigned, never the locally-requested one',
    );
  });

  test('live mode, offline with nothing cached: falls back to the local '
      'instance, explicitly marked provisionalPendingServer (never passed '
      'off as confirmed)', () async {
    final client = _ThrowingAssignmentClient();

    final container = ProviderContainer(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(
          FakeSecureKeyValueStore(),
        ),
        backendModeProvider.overrideWithValue(BackendMode.liveSupabase),
        currentBackendUserIdProvider.overrideWithValue(_userId),
        missionAssignmentClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    final resolved = await _resolve(container);
    final local = container.read(missionInstanceProvider);

    expect(resolved, isNotNull);
    expect(
      resolved!.authority,
      MissionInstanceAuthority.provisionalPendingServer,
    );
    expect(resolved.instance.instanceId, local!.instanceId);
  });

  test('live mode, offline but a confirmed assignment was cached for today: '
      'reuses that authoritative id — never a fresh local one', () async {
    final store = FakeSecureKeyValueStore();
    // Pre-populate the cache exactly as a prior successful resolution
    // would have — same shape CachedMissionAssignmentStore itself
    // writes, so this doesn't depend on that class's internals beyond
    // its own documented key convention.
    await store.write(
      'forge.mission_assignment.$_userId.2026-08-05',
      '{"missionInstanceId":"cached-server-id",'
          '"missionDefinitionId":"fit-stretch-10",'
          '"assignedDate":"2026-08-05T00:00:00.000Z"}',
    );

    final client = _ThrowingAssignmentClient();

    final container = ProviderContainer(
      overrides: [
        secureKeyValueStoreProvider.overrideWithValue(store),
        backendModeProvider.overrideWithValue(BackendMode.liveSupabase),
        currentBackendUserIdProvider.overrideWithValue(_userId),
        missionAssignmentClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    final resolved = await _resolve(container);

    expect(resolved, isNotNull);
    expect(resolved!.authority, MissionInstanceAuthority.serverConfirmed);
    expect(resolved.instance.instanceId, 'cached-server-id');
  });
}
