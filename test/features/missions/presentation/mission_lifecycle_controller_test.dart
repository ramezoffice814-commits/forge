import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/backend_mode.dart';
import 'package:forge/core/backend/backend_providers.dart';
import 'package:forge/core/backend/mission_assignment_client.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/features/missions/domain/aggregates/mission_lifecycle_state.dart';
import 'package:forge/features/missions/domain/aggregates/mission_transition_failure.dart';
import 'package:forge/features/missions/presentation/providers/mission_instance_provider.dart';
import 'package:forge/features/missions/presentation/providers/mission_lifecycle_controller.dart';
import 'package:forge/features/missions/presentation/providers/mission_lifecycle_state.dart';
import 'package:forge/features/missions/presentation/providers/resolved_mission_instance_controller.dart';

import '../../../support/fake_secure_key_value_store.dart';

// resolvedMissionInstanceProvider, not missionInstanceProvider directly
// (Roadmap Item 13C): MissionLifecycleController.build() now watches the
// *resolved* instance, so a test must await that controller's readiness
// too, not just mission selection's — mock mode still resolves to the
// same id missionInstanceProvider would have given, one microtask later.
Future<String> _readyInstanceId(ProviderContainer container) async {
  await container
      .read(resolvedMissionInstanceControllerProvider.notifier)
      .ready;
  return container.read(resolvedMissionInstanceProvider)!.instance.instanceId;
}

void main() {
  test('build() resolves Ready for today\'s real mission instance', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final instanceId = await _readyInstanceId(container);

    final state = container.read(
      missionLifecycleControllerProvider(instanceId),
    );
    expect(state, isA<MissionLifecycleReady>());
    expect(
      (state as MissionLifecycleReady).aggregate.lifecycleState,
      MissionLifecycleState.assigned,
    );
  });

  test('an unknown mission id resolves to NotFound, never a crash', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _readyInstanceId(container);

    final state = container.read(
      missionLifecycleControllerProvider('not-a-real-instance-id'),
    );
    expect(state, isA<MissionLifecycleNotFound>());
  });

  test(
    'accept() then start() advances the aggregate through both states',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final instanceId = await _readyInstanceId(container);
      final notifier = container.read(
        missionLifecycleControllerProvider(instanceId).notifier,
      );

      await notifier.accept();
      var state =
          container.read(missionLifecycleControllerProvider(instanceId))
              as MissionLifecycleReady;
      expect(state.aggregate.lifecycleState, MissionLifecycleState.accepted);

      await notifier.start();
      state =
          container.read(missionLifecycleControllerProvider(instanceId))
              as MissionLifecycleReady;
      expect(state.aggregate.lifecycleState, MissionLifecycleState.active);
    },
  );

  test('an illegal action surfaces a typed failure without crashing and '
      'leaves the aggregate unchanged', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final instanceId = await _readyInstanceId(container);
    final notifier = container.read(
      missionLifecycleControllerProvider(instanceId).notifier,
    );

    // start() before accept() is illegal from `assigned`.
    await notifier.start();

    final state =
        container.read(missionLifecycleControllerProvider(instanceId))
            as MissionLifecycleReady;
    expect(state.aggregate.lifecycleState, MissionLifecycleState.assigned);
    expect(state.lastFailure, isNotNull);
    expect(
      state.lastFailure!.reason,
      TransitionFailureReason.invalidTransition,
    );
  });

  test(
    'dismissFailure clears lastFailure without touching the aggregate',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final instanceId = await _readyInstanceId(container);
      final notifier = container.read(
        missionLifecycleControllerProvider(instanceId).notifier,
      );

      await notifier.start(); // illegal, sets lastFailure
      notifier.dismissFailure();

      final state =
          container.read(missionLifecycleControllerProvider(instanceId))
              as MissionLifecycleReady;
      expect(state.lastFailure, isNull);
      expect(state.aggregate.lifecycleState, MissionLifecycleState.assigned);
    },
  );

  test(
    'view() then accept() records both events in the aggregate\'s history',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final instanceId = await _readyInstanceId(container);
      final notifier = container.read(
        missionLifecycleControllerProvider(instanceId).notifier,
      );

      await notifier.view();
      await notifier.accept();

      final state =
          container.read(missionLifecycleControllerProvider(instanceId))
              as MissionLifecycleReady;
      // assigned + viewed + accepted = at least 3 events on the stream.
      expect(state.aggregate.events.length, greaterThanOrEqualTo(3));
    },
  );

  test(
    'Roadmap Item 13C: in live mode, the locally-generated id is never '
    'accepted — only the resolved (server-confirmed) id resolves to '
    'Ready, proving a caller can\'t accidentally lose the server id',
    () async {
      final client = _FakeAssignmentClient();
      final container = ProviderContainer(
        overrides: [
          secureKeyValueStoreProvider.overrideWithValue(
            FakeSecureKeyValueStore(),
          ),
          backendModeProvider.overrideWithValue(BackendMode.liveSupabase),
          currentBackendUserIdProvider.overrideWithValue('user-13c'),
          missionAssignmentClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      final serverInstanceId = await _readyInstanceId(container);
      expect(serverInstanceId, 'server-confirmed-id-13c');

      final localInstanceId = container
          .read(missionInstanceProvider)!
          .instanceId;
      expect(
        localInstanceId,
        isNot(serverInstanceId),
        reason:
            'the fixture is only meaningful if the local and server '
            'ids genuinely differ',
      );

      // The resolved (server) id works.
      expect(
        container.read(missionLifecycleControllerProvider(serverInstanceId)),
        isA<MissionLifecycleReady>(),
      );
      // The old local-only id — what a caller would get by mistakenly
      // reading missionInstanceProvider directly instead of the resolved
      // provider — must NOT resolve to Ready in live mode.
      expect(
        container.read(missionLifecycleControllerProvider(localInstanceId)),
        isA<MissionLifecycleNotFound>(),
      );
    },
  );
}

class _FakeAssignmentClient implements MissionAssignmentClient {
  @override
  Future<MissionAssignmentResult> assignDailyMission({
    required String commandId,
    required String idempotencyKey,
    String? requestedMissionDefinitionId,
    String? requestedCategory,
  }) async {
    return MissionAssignmentResult(
      missionInstanceId: 'server-confirmed-id-13c',
      missionDefinitionId: requestedMissionDefinitionId ?? 'fit-stretch-10',
      assignedDate: DateTime.utc(2026, 8, 5),
      serverTimestamp: DateTime.utc(2026, 8, 5),
      confirmationId: 'conf-13c',
    );
  }
}
