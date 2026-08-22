import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/mission_aggregate.dart';
import '../../domain/aggregates/mission_lifecycle_exception.dart';
import '../../domain/entities/mission_instance.dart';
import '../../domain/enums/rejection_reason.dart';
import '../../domain/events/mission_event.dart';
import '../../domain/progress/mission_progress_state.dart';
import '../../domain/repositories/mission_event_repository.dart';
import '../../domain/usecases/abandon_mission_usecase.dart';
import '../../domain/usecases/accept_mission_usecase.dart';
import '../../domain/usecases/assign_mission_usecase.dart';
import '../../domain/usecases/pause_mission_usecase.dart';
import '../../domain/usecases/reject_mission_usecase.dart';
import '../../domain/usecases/resume_mission_usecase.dart';
import '../../domain/usecases/start_mission_usecase.dart';
import '../../domain/usecases/submit_mission_usecase.dart';
import '../../domain/usecases/undo_mission_completion_usecase.dart';
import '../../domain/usecases/update_mission_progress_usecase.dart';
import '../../domain/usecases/view_mission_usecase.dart';
import 'mission_event_repository_provider.dart';
import 'mission_instance_provider.dart';
import 'mission_lifecycle_state.dart';
import 'mission_providers.dart';
import 'mission_selection_controller.dart';
import 'resolved_mission_instance_controller.dart';

/// One controller instance per mission id (a `NotifierProvider.family`), so
/// `ActiveMissionPage` and anything else reading this mission's lifecycle
/// always agree on which stream they're watching. This class owns *when*
/// to call a use case and how to fold its result/failure into state — it
/// never reimplements a transition rule itself; every rule lives in
/// `MissionAggregate`/`MissionLifecycleTransitions` or one of the use cases.
class MissionLifecycleController
    extends FamilyNotifier<MissionLifecycleControllerState, String> {
  late MissionEventRepository _repository;
  late String _userId;
  StreamSubscription<List<MissionEvent>>? _subscription;

  @override
  MissionLifecycleControllerState build(String missionInstanceId) {
    // resolvedMissionInstanceProvider, not missionInstanceProvider
    // directly (Roadmap Item 13C): in live/staging mode this controller
    // is keyed by the *server-confirmed* mission id, which never equals
    // missionInstanceProvider's own locally-generated id — reading the
    // local provider here would make the guard below permanently fail
    // to match and this mission's lifecycle would never resolve past
    // "not found". In mock mode the two are the same value, so this is a
    // behavior-preserving swap there.
    final instance = ref.watch(resolvedMissionInstanceProvider)?.instance;
    _repository = ref.watch(missionEventRepositoryProvider);
    _userId = ref.watch(currentMissionUserIdProvider);

    ref.onDispose(() => _subscription?.cancel());

    if (instance == null || instance.instanceId != missionInstanceId) {
      _subscription?.cancel();
      _subscription = null;
      return MissionLifecycleNotFound(missionInstanceId);
    }

    _subscription?.cancel();
    _subscription = _repository
        .observeMissionEvents(missionInstanceId)
        .listen((events) => _onEvents(instance, events));

    final existingEvents = _repository.eventsForMission(missionInstanceId);
    // No deferred/microtask assignment here on purpose: appending
    // `MissionAssigned` happens synchronously within `_run`, immediately
    // before whatever action triggered it — see `_run`'s doc comment for
    // why. A zero-event aggregate already reports lifecycle `assigned` (see
    // `MissionAggregate.rehydrate`'s default), so nothing here depends on
    // that event actually existing yet; it's purely for the audit trail.
    return MissionLifecycleReady(
      MissionAggregate.rehydrate(instance, existingEvents),
    );
  }

  void _onEvents(MissionInstance instance, List<MissionEvent> events) {
    final current = state;
    final lastFailure = current is MissionLifecycleReady
        ? current.lastFailure
        : null;
    state = MissionLifecycleReady(
      MissionAggregate.rehydrate(instance, events),
      lastFailure: lastFailure,
    );
  }

  MissionAggregate? get _currentAggregate {
    final current = state;
    return current is MissionLifecycleReady ? current.aggregate : null;
  }

  /// Every action funnels through here, which is also the one place that
  /// guarantees `MissionAssigned` exists before anything else is appended.
  /// Doing this *inside* the same awaited call chain as the actual action —
  /// rather than as a separate deferred `Future.microtask` fired from
  /// `build()` — is deliberate: two independently-scheduled microtasks
  /// (one assigning, one accepting) have no guaranteed relative order, and
  /// `MissionAggregate.rehydrate` trusts `assigned` to be the very first
  /// event chronologically. Awaiting it first, right here, removes that
  /// race entirely.
  Future<void> _run(
    Future<MissionAggregate> Function(MissionAggregate aggregate) action,
  ) async {
    final aggregate = _currentAggregate;
    if (aggregate == null) return;
    try {
      final assigned = aggregate.events.isEmpty
          ? await AssignMissionUseCase(_repository)(
              instance: aggregate.instance,
              userId: _userId,
            )
          : aggregate;
      final updated = await action(assigned);
      state = MissionLifecycleReady(updated);
    } on MissionLifecycleException catch (e) {
      state = MissionLifecycleReady(aggregate, lastFailure: e.failure);
    }
  }

  Future<void> view() => _run(
    (aggregate) =>
        ViewMissionUseCase(_repository)(aggregate: aggregate, userId: _userId),
  );

  Future<void> accept() => _run(
    (aggregate) => AcceptMissionUseCase(_repository)(
      aggregate: aggregate,
      userId: _userId,
    ),
  );

  Future<void> start({String? clientSessionId}) => _run(
    (aggregate) => StartMissionUseCase(_repository)(
      aggregate: aggregate,
      userId: _userId,
      clientSessionId: clientSessionId,
    ),
  );

  Future<void> pause() => _run(
    (aggregate) =>
        PauseMissionUseCase(_repository)(aggregate: aggregate, userId: _userId),
  );

  Future<void> resume() => _run(
    (aggregate) => ResumeMissionUseCase(_repository)(
      aggregate: aggregate,
      userId: _userId,
    ),
  );

  Future<void> updateProgress(
    MissionProgressState proposed, {
    bool isCorrection = false,
  }) => _run(
    (aggregate) => UpdateMissionProgressUseCase(_repository)(
      aggregate: aggregate,
      userId: _userId,
      proposed: proposed,
      isCorrection: isCorrection,
    ),
  );

  Future<void> submit() => _run(
    (aggregate) => SubmitMissionUseCase(_repository)(
      aggregate: aggregate,
      userId: _userId,
    ),
  );

  Future<void> undoCompletion({String? reason}) => _run(
    (aggregate) => UndoMissionCompletionUseCase(_repository)(
      aggregate: aggregate,
      userId: _userId,
      reason: reason,
    ),
  );

  Future<void> abandon({String? reason}) => _run(
    (aggregate) => AbandonMissionUseCase(_repository)(
      aggregate: aggregate,
      userId: _userId,
      reason: reason,
    ),
  );

  /// Hands off to the selection engine for a replacement *before* recording
  /// the rejection, so `MissionRejected.replacementMissionInstanceId` is
  /// known at construction time — no event is ever edited after the fact.
  Future<void> reject(RejectionReason reason) async {
    final aggregate = _currentAggregate;
    if (aggregate == null) return;
    await ref
        .read(missionSelectionControllerProvider.notifier)
        .rejectMission(reason);
    final replacement = ref.read(missionInstanceProvider);
    await _run(
      (aggregate) => RejectMissionUseCase(_repository)(
        aggregate: aggregate,
        userId: _userId,
        reason: reason,
        replacementMissionInstanceId: replacement?.instanceId,
      ),
    );
  }

  /// Explicit dismissal so a failed action's message never disappears
  /// before the user has actually read it (see `MissionLifecycleReady
  /// .lastFailure`'s doc comment).
  void dismissFailure() {
    final current = state;
    if (current is MissionLifecycleReady) {
      state = current.clearFailure();
    }
  }
}

final missionLifecycleControllerProvider =
    NotifierProvider.family<
      MissionLifecycleController,
      MissionLifecycleControllerState,
      String
    >(MissionLifecycleController.new);
