import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_error_ux.dart';
import '../../../../core/backend/backend_providers.dart';
import '../../../../core/backend/commands/accept_mission_command.dart';
import '../../../../core/backend/commands/cancel_mission_command.dart';
import '../../../../core/backend/commands/record_mission_progress_command.dart';
import '../../../../core/backend/commands/start_mission_command.dart';
import '../../../../core/backend/commands/submit_mission_command.dart';
import '../../../../core/backend/idempotency_key_generator.dart';
import '../../../../core/backend/mission_progress_payload_mapper.dart';
import '../../../../core/backend/raw_backend_response.dart';
import '../../../../core/backend/reconciliation/mission_command_reconciliation.dart';
import '../../../../core/backend/request_id_generator.dart';
import '../../../../core/backend/responses/server_validation_status.dart';
import '../../../../core/backend/sync_queueing_backend_client.dart';
import '../../../competition/presentation/providers/competition_controller.dart';
import '../../../progression/presentation/providers/progression_controller.dart';
import '../../domain/aggregates/mission_aggregate.dart';
import '../../domain/aggregates/mission_lifecycle_state.dart' as lifecycle;
import '../../domain/progress/mission_progress_state.dart';
import 'mission_lifecycle_controller.dart';
import 'mission_lifecycle_state.dart';

/// Where this mission's local (provisional) state currently stands
/// relative to the server — spec section 5's "clearly distinguish
/// localOnly / provisional / serverConfirmed", kept intentionally
/// coarse ("subtle indicators are enough").
enum MissionSyncStatus {
  /// No backend-relevant action attempted yet for this mission.
  idle,

  /// A command was queued offline (spec section 3's "queue safe
  /// provisional command... never claim server confirmation").
  queued,

  /// A request is in flight.
  syncing,

  /// The server confirmed this command.
  confirmed,

  /// The server rejected this command outright.
  rejected,

  /// Automatic reconciliation could not safely resolve this on its own
  /// (spec section 6).
  conflict,
}

@immutable
class MissionBackendSyncState {
  const MissionBackendSyncState({
    this.status = MissionSyncStatus.idle,
    this.lastErrorUx,
    this.lastReward,
  });

  final MissionSyncStatus status;
  final BackendErrorUxState? lastErrorUx;

  /// Only ever set on a genuinely server-confirmed `submit-mission`
  /// response — never fabricated locally (spec section 5: "never
  /// display provisional XP as confirmed XP").
  final ConfirmedMissionReward? lastReward;

  MissionBackendSyncState copyWith({
    MissionSyncStatus? status,
    BackendErrorUxState? lastErrorUx,
    ConfirmedMissionReward? lastReward,
    bool clearError = false,
  }) {
    return MissionBackendSyncState(
      status: status ?? this.status,
      lastErrorUx: clearError ? null : (lastErrorUx ?? this.lastErrorUx),
      lastReward: lastReward ?? this.lastReward,
    );
  }
}

/// Bridges the local, event-sourced mission lifecycle
/// (`MissionLifecycleController`) to the Phase 10C authoritative backend
/// — the same architectural shape as the existing
/// `missionCompletionBridgeProvider`/`competitionCompletionBridgeProvider`
/// (react to a lifecycle transition, forward a narrow fact, never touch
/// the source domain's own logic). This class never mutates
/// `MissionAggregate`/`MissionLifecycleController` — the local domain
/// stays the immediate, optimistic source of truth for UI exactly as it
/// is today; this only *additionally* sends the matching command to
/// [backendClientProvider] and records what the server said.
///
/// Known gap, found and documented during Roadmap Item 13B staging
/// verification (superseding the old Phase 10D note this replaced): a
/// real end-to-end round trip needs the `missionInstanceId` these
/// commands carry to match a real server-side `mission_instances` row.
/// Phase 11's `forge_assign_daily_mission`/`SupabaseMissionAssignmentClient`
/// creates that row and returns its authoritative id — but nothing wires
/// that id into [missionInstanceProvider], which still derives its own
/// purely-local, deterministic id (`<missionId>-<dateKey>`) regardless of
/// backend mode. In live mode today, that means every command this class
/// dispatches carries an id the server has never heard of and receives
/// `mission_not_found` — not because assignment doesn't exist, but
/// because nothing yet hands its result to the rest of the app. This
/// class's job is the wiring/reconciliation *after* a valid instance id
/// exists, which is real and independently correct regardless of that
/// gap; closing the gap itself is out of scope for this pass.
class MissionBackendSyncController
    extends FamilyNotifier<MissionBackendSyncState, String> {
  int _sequence = 0;
  final Set<String> _dispatchedStages = {};
  final _idempotencyKeys = const DeterministicIdempotencyKeyGenerator();
  late final RequestIdGenerator _requestIds = SequentialRequestIdGenerator(
    prefix: missionInstanceIdArg,
  );
  late String missionInstanceIdArg;

  @override
  MissionBackendSyncState build(String missionInstanceId) {
    missionInstanceIdArg = missionInstanceId;
    ref.listen<MissionLifecycleControllerState>(
      missionLifecycleControllerProvider(missionInstanceId),
      (previous, next) => _onLifecycleChange(missionInstanceId, next),
    );
    return const MissionBackendSyncState();
  }

  void _onLifecycleChange(
    String missionInstanceId,
    MissionLifecycleControllerState next,
  ) {
    if (next is! MissionLifecycleReady) return;
    final aggregate = next.aggregate;
    switch (aggregate.lifecycleState) {
      case lifecycle.MissionLifecycleState.accepted:
        _dispatchOnce('accepted', () => _sendAccept(missionInstanceId));
      case lifecycle.MissionLifecycleState.active:
        _dispatchOnce('started', () => _sendStart(missionInstanceId));
      case lifecycle.MissionLifecycleState.completed:
        _dispatchOnce(
          'submitted',
          () => _sendSubmit(missionInstanceId, aggregate),
        );
      case lifecycle.MissionLifecycleState.abandoned:
        _dispatchOnce('cancelled', () => _sendCancel(missionInstanceId));
      default:
        break;
    }
  }

  void _dispatchOnce(String stage, Future<void> Function() action) {
    if (!_dispatchedStages.add(stage)) return;
    action();
  }

  String? get _authenticatedUserId => ref.read(currentBackendUserIdProvider);

  Future<void> _sendAccept(String missionInstanceId) async {
    final userId = _authenticatedUserId;
    if (userId == null) return; // not signed in — nothing to sync yet.
    _sequence += 1;
    final command = AcceptMissionCommand(
      commandId: _requestIds.next(),
      missionInstanceId: missionInstanceId,
      userId: userId,
      timestamp: DateTime.now().toUtc(),
      sequence: _sequence,
      idempotencyKey: _idempotencyKeys.generate(
        missionInstanceId: missionInstanceId,
        commandType: 'accept',
        sequence: _sequence,
      ),
    );
    await _sendVerdictOnly(
      () => ref.read(backendClientProvider).acceptMission(command),
      statusOf: (result) => result.status,
    );
  }

  Future<void> _sendStart(String missionInstanceId) async {
    final userId = _authenticatedUserId;
    if (userId == null) return;
    _sequence += 1;
    final command = StartMissionCommand(
      commandId: _requestIds.next(),
      missionInstanceId: missionInstanceId,
      userId: userId,
      timestamp: DateTime.now().toUtc(),
      sequence: _sequence,
      idempotencyKey: _idempotencyKeys.generate(
        missionInstanceId: missionInstanceId,
        commandType: 'start',
        sequence: _sequence,
      ),
    );
    await _sendVerdictOnly(
      () => ref.read(backendClientProvider).startMission(command),
      statusOf: (result) => result.status,
    );
  }

  Future<void> _sendCancel(String missionInstanceId) async {
    final userId = _authenticatedUserId;
    if (userId == null) return;
    _sequence += 1;
    final command = CancelMissionCommand(
      commandId: _requestIds.next(),
      missionInstanceId: missionInstanceId,
      userId: userId,
      timestamp: DateTime.now().toUtc(),
      sequence: _sequence,
      idempotencyKey: _idempotencyKeys.generate(
        missionInstanceId: missionInstanceId,
        commandType: 'cancel',
        sequence: _sequence,
      ),
    );
    await _sendVoid(() {
      return ref.read(backendClientProvider).cancelMission(command);
    });
  }

  /// Explicit, caller-invoked progress sync — not auto-triggered on
  /// every local `updateProgress` call (documented scope limit: local
  /// [MissionProgressState] subtypes don't carry value equality, so
  /// reliably detecting "did progress actually change" from a bare
  /// `ref.listen` diff isn't safe without risking duplicate/needless
  /// sends; a caller that already knows a real update just happened —
  /// e.g. right after `MissionLifecycleController.updateProgress`
  /// resolves — can call this directly).
  Future<void> dispatchProgress(
    String missionInstanceId,
    MissionProgressState progress,
  ) async {
    final userId = _authenticatedUserId;
    if (userId == null) return;
    _sequence += 1;
    final payload = mapMissionProgressToPayload(progress);
    final command = RecordMissionProgressCommand(
      commandId: _requestIds.next(),
      missionInstanceId: missionInstanceId,
      userId: userId,
      timestamp: DateTime.now().toUtc(),
      sequence: _sequence,
      idempotencyKey: _idempotencyKeys.generate(
        missionInstanceId: missionInstanceId,
        commandType: 'progress',
        sequence: _sequence,
      ),
      progressPayload: payload.toCommandFields(),
    );
    await _sendVerdictOnly(
      () => ref.read(backendClientProvider).recordProgress(command),
      statusOf: (result) => result.status,
    );
  }

  Future<void> _sendSubmit(
    String missionInstanceId,
    MissionAggregate aggregate,
  ) async {
    final userId = _authenticatedUserId;
    if (userId == null) return;
    _sequence += 1;
    final payload = mapMissionProgressToPayload(aggregate.progressState);
    final command = SubmitMissionCommand(
      commandId: _requestIds.next(),
      missionInstanceId: missionInstanceId,
      userId: userId,
      timestamp: DateTime.now().toUtc(),
      sequence: _sequence,
      idempotencyKey: _idempotencyKeys.generate(
        missionInstanceId: missionInstanceId,
        commandType: 'submit',
        sequence: _sequence,
      ),
      completionPayload: payload.toCommandFields(),
    );

    state = state.copyWith(status: MissionSyncStatus.syncing, clearError: true);
    try {
      final response = await ref
          .read(backendClientProvider)
          .submitMission(command);
      final result = response.payload;

      ConfirmedMissionReward? reward;
      if (result.status == ServerValidationStatus.accepted) {
        reward = ConfirmedMissionReward(
          confirmedXpReward: result.confirmedXpReward.value,
          confirmedTotalXp: result.progressionUpdate.value.confirmedTotalXp,
          previousLevel: result.progressionUpdate.value.previousLevel,
          newLevel: result.progressionUpdate.value.newLevel,
          achievementUpdates: result.achievementUpdates.value,
          competitionScoreUpdate: result.competitionScoreUpdate.value,
        );
      }

      final outcome = MissionSubmissionReconciliation.reconcile(
        serverStatus: result.status,
        reward: reward,
      );
      await _applyOutcome(missionInstanceId, outcome);
    } on CommandQueuedForSyncException {
      state = state.copyWith(status: MissionSyncStatus.queued);
    } catch (e) {
      state = state.copyWith(
        status: MissionSyncStatus.conflict,
        lastErrorUx: mapBackendErrorToUx(null, e.toString()),
      );
    }
  }

  Future<void> _applyOutcome(
    String missionInstanceId,
    MissionSubmissionOutcome outcome,
  ) async {
    final reward = outcome.reward;
    if (outcome.base.outcome == ReconciliationOutcome.accepted &&
        reward != null) {
      final now = DateTime.now().toUtc();
      await ref
          .read(progressionControllerProvider.notifier)
          .applyServerConfirmedReward(
            missionInstanceId: missionInstanceId,
            confirmedTotalXp: reward.confirmedTotalXp,
            confirmedLevel: reward.newLevel,
            confirmedAchievementIds: reward.achievementUpdates,
            confirmedAt: now,
          );
      if (reward.competitionScoreUpdate > 0) {
        ref
            .read(competitionControllerProvider.notifier)
            .applyServerConfirmedScore(
              missionInstanceId: missionInstanceId,
              confirmedScoreDelta: reward.competitionScoreUpdate,
              integrityStatus: 'clean',
              confirmedAt: now,
            );
      }
      state = state.copyWith(
        status: MissionSyncStatus.confirmed,
        lastReward: reward,
      );
      return;
    }

    state = state.copyWith(
      status: _statusFor(outcome.base.outcome),
      lastErrorUx: mapBackendErrorToUx(
        outcome.base.reasonCode,
        outcome.base.reasonCode ?? 'Submission was not confirmed.',
      ),
    );
  }

  Future<void> _sendVerdictOnly<T>(
    Future<RawBackendResponse<T>> Function() call, {
    required ServerValidationStatus Function(T) statusOf,
  }) async {
    state = state.copyWith(status: MissionSyncStatus.syncing, clearError: true);
    try {
      final response = await call();
      final result = MissionCommandReconciliation.reconcile(
        serverStatus: statusOf(response.payload),
      );
      state = state.copyWith(
        status: _statusFor(result.outcome),
        lastErrorUx: result.outcome == ReconciliationOutcome.accepted
            ? null
            : mapBackendErrorToUx(result.reasonCode, 'Not confirmed.'),
      );
    } on CommandQueuedForSyncException {
      state = state.copyWith(status: MissionSyncStatus.queued);
    } catch (e) {
      state = state.copyWith(
        status: MissionSyncStatus.conflict,
        lastErrorUx: mapBackendErrorToUx(null, e.toString()),
      );
    }
  }

  Future<void> _sendVoid(Future<void> Function() call) async {
    state = state.copyWith(status: MissionSyncStatus.syncing, clearError: true);
    try {
      await call();
      state = state.copyWith(status: MissionSyncStatus.confirmed);
    } on CommandQueuedForSyncException {
      state = state.copyWith(status: MissionSyncStatus.queued);
    } catch (e) {
      state = state.copyWith(
        status: MissionSyncStatus.conflict,
        lastErrorUx: mapBackendErrorToUx(null, e.toString()),
      );
    }
  }

  MissionSyncStatus _statusFor(ReconciliationOutcome outcome) {
    return switch (outcome) {
      ReconciliationOutcome.accepted ||
      ReconciliationOutcome.exactMatch ||
      ReconciliationOutcome.idempotencyReplay => MissionSyncStatus.confirmed,
      ReconciliationOutcome.rejectedByServer => MissionSyncStatus.rejected,
      ReconciliationOutcome.staleSequence ||
      ReconciliationOutcome.serverAhead => MissionSyncStatus.conflict,
      ReconciliationOutcome.conflict => MissionSyncStatus.conflict,
    };
  }
}

final missionBackendSyncControllerProvider =
    NotifierProvider.family<
      MissionBackendSyncController,
      MissionBackendSyncState,
      String
    >(MissionBackendSyncController.new);
