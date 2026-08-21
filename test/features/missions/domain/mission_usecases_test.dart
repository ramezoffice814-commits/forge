import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/data/local/in_memory_mission_event_repository.dart';
import 'package:forge/features/missions/domain/aggregates/mission_aggregate.dart';
import 'package:forge/features/missions/domain/aggregates/mission_lifecycle_exception.dart';
import 'package:forge/features/missions/domain/aggregates/mission_lifecycle_state.dart';
import 'package:forge/features/missions/domain/aggregates/mission_reward_state.dart';
import 'package:forge/features/missions/domain/aggregates/mission_transition_failure.dart';
import 'package:forge/features/missions/domain/enums/rejection_reason.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_definition.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_state.dart';
import 'package:forge/features/missions/domain/usecases/abandon_mission_usecase.dart';
import 'package:forge/features/missions/domain/usecases/accept_mission_usecase.dart';
import 'package:forge/features/missions/domain/usecases/assign_mission_usecase.dart';
import 'package:forge/features/missions/domain/usecases/pause_mission_usecase.dart';
import 'package:forge/features/missions/domain/usecases/reject_mission_usecase.dart';
import 'package:forge/features/missions/domain/usecases/resume_mission_usecase.dart';
import 'package:forge/features/missions/domain/usecases/start_mission_usecase.dart';
import 'package:forge/features/missions/domain/usecases/submit_mission_usecase.dart';
import 'package:forge/features/missions/domain/usecases/undo_mission_completion_usecase.dart';
import 'package:forge/features/missions/domain/usecases/update_mission_progress_usecase.dart';
import 'package:forge/features/missions/domain/sessions/mission_clock.dart';

import '../../../support/mission_lifecycle_test_helpers.dart';

void main() {
  late InMemoryMissionEventRepository repository;
  final instance = testMissionInstance(
    progressDefinition: const BinaryProgressDefinition(),
  );

  setUp(() => repository = InMemoryMissionEventRepository());
  tearDown(() => repository.dispose());

  Future<MissionAggregate> assign({MissionClock? clock}) =>
      AssignMissionUseCase(
        repository,
        clock: clock ?? const SystemMissionClock(),
      )(instance: instance, userId: testUserId);

  test('the full happy path advances assigned -> accepted -> active -> '
      'submitted -> completed', () async {
    var aggregate = await assign();
    expect(aggregate.lifecycleState, MissionLifecycleState.assigned);

    aggregate = await AcceptMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    expect(aggregate.lifecycleState, MissionLifecycleState.accepted);

    aggregate = await StartMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    expect(aggregate.lifecycleState, MissionLifecycleState.active);

    aggregate = await UpdateMissionProgressUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
      proposed: const BinaryProgressState(completed: true),
    );
    expect((aggregate.progressState as BinaryProgressState).completed, isTrue);

    aggregate = await SubmitMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    expect(aggregate.lifecycleState, MissionLifecycleState.completed);
    expect(aggregate.rewardState, MissionRewardState.pendingServerConfirmation);
  });

  test('submitting without meeting completion criteria fails validation and '
      'stays open', () async {
    var aggregate = await assign();
    aggregate = await AcceptMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    aggregate = await StartMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );

    aggregate = await SubmitMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    expect(aggregate.lifecycleState, MissionLifecycleState.validationFailed);
    expect(aggregate.lastValidationFailureReasons, isNotEmpty);
    expect(aggregate.canResume, isTrue);
  });

  test('pause then resume returns to active', () async {
    var aggregate = await assign();
    aggregate = await AcceptMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    aggregate = await StartMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    aggregate = await PauseMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    expect(aggregate.lifecycleState, MissionLifecycleState.paused);

    aggregate = await ResumeMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    expect(aggregate.lifecycleState, MissionLifecycleState.active);
  });

  test(
    'accepting an already-accepted mission throws a typed failure',
    () async {
      var aggregate = await assign();
      aggregate = await AcceptMissionUseCase(repository)(
        aggregate: aggregate,
        userId: testUserId,
      );

      expect(
        () => AcceptMissionUseCase(repository)(
          aggregate: aggregate,
          userId: testUserId,
        ),
        throwsA(
          isA<MissionLifecycleException>().having(
            (e) => e.failure.reason,
            'reason',
            anyOf(
              TransitionFailureReason.invalidTransition,
              TransitionFailureReason.duplicateEvent,
            ),
          ),
        ),
      );
    },
  );

  test(
    'starting a mission that was never accepted throws invalidTransition',
    () async {
      final aggregate = await assign();
      expect(
        () => StartMissionUseCase(repository)(
          aggregate: aggregate,
          userId: testUserId,
        ),
        throwsA(
          isA<MissionLifecycleException>().having(
            (e) => e.failure.reason,
            'reason',
            TransitionFailureReason.invalidTransition,
          ),
        ),
      );
    },
  );

  test('undoing completion returns lifecycle to active', () async {
    var aggregate = await assign();
    aggregate = await AcceptMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    aggregate = await StartMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    aggregate = await UpdateMissionProgressUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
      proposed: const BinaryProgressState(completed: true),
    );
    aggregate = await SubmitMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    expect(aggregate.lifecycleState, MissionLifecycleState.completed);

    aggregate = await UndoMissionCompletionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    expect(aggregate.lifecycleState, MissionLifecycleState.active);
    expect(aggregate.rewardState, MissionRewardState.none);
  });

  test('undoing completion outside the undo window throws', () async {
    final clock = FakeMissionClock();
    var aggregate = await assign(clock: clock);
    aggregate = await AcceptMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    aggregate = await StartMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    aggregate = await UpdateMissionProgressUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
      proposed: const BinaryProgressState(completed: true),
    );
    aggregate = await SubmitMissionUseCase(repository, clock: clock)(
      aggregate: aggregate,
      userId: testUserId,
    );

    clock.advance(const Duration(minutes: 30));
    expect(
      () => UndoMissionCompletionUseCase(repository, clock: clock)(
        aggregate: aggregate,
        userId: testUserId,
      ),
      throwsA(
        isA<MissionLifecycleException>().having(
          (e) => e.failure.reason,
          'reason',
          TransitionFailureReason.outsideUndoWindow,
        ),
      ),
    );
  });

  test('rejecting an assigned mission moves it to abandoned and records the '
      'replacement id', () async {
    final aggregate = await assign();
    final rejected = await RejectMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
      reason: RejectionReason.tooDifficult,
      replacementMissionInstanceId: 'replacement-1',
    );
    expect(rejected.lifecycleState, MissionLifecycleState.abandoned);
    expect(rejected.replacementMissionInstanceId, 'replacement-1');
  });

  test('abandoning an active mission is terminal', () async {
    var aggregate = await assign();
    aggregate = await AcceptMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    aggregate = await StartMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
    );
    aggregate = await AbandonMissionUseCase(repository)(
      aggregate: aggregate,
      userId: testUserId,
      reason: 'no longer relevant',
    );
    expect(aggregate.lifecycleState, MissionLifecycleState.abandoned);
    expect(aggregate.canAbandon, isFalse);
  });
}
