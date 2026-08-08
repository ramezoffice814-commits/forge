import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/aggregates/mission_lifecycle_state.dart';
import 'package:forge/features/missions/domain/aggregates/mission_transition_failure.dart';
import 'package:forge/features/missions/presentation/providers/mission_instance_provider.dart';
import 'package:forge/features/missions/presentation/providers/mission_lifecycle_controller.dart';
import 'package:forge/features/missions/presentation/providers/mission_lifecycle_state.dart';
import 'package:forge/features/missions/presentation/providers/mission_selection_controller.dart';

Future<String> _readyInstanceId(ProviderContainer container) async {
  await container.read(missionSelectionControllerProvider.notifier).ready;
  return container.read(missionInstanceProvider)!.instanceId;
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
}
