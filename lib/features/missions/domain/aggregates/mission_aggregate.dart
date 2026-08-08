import 'package:flutter/foundation.dart';

import '../entities/mission_instance.dart';
import '../events/mission_event.dart';
import '../events/mission_event_source.dart';
import '../progress/mission_progress_state.dart';
import '../sessions/mission_session.dart';
import '../sessions/mission_session_reducer.dart';
import 'mission_lifecycle_state.dart';
import 'mission_reward_state.dart';

/// The current, fully-derived state of one mission — never independently
/// mutated. [rehydrate] is a pure function: the same [instance] and the
/// same ordered [events] always produce an identical aggregate, which is
/// what makes this auditable and safe to recompute at any time (a crash
/// mid-session loses nothing — replaying the event log rebuilds exactly
/// where things were).
@immutable
class MissionAggregate {
  const MissionAggregate({
    required this.instance,
    required this.events,
    required this.lifecycleState,
    required this.progressState,
    required this.rewardState,
    required this.totalActiveDuration,
    required this.totalPausedDuration,
    required this.sessionHistory,
    required this.pendingSyncCount,
    this.acceptedAt,
    this.startedAt,
    this.lastActivityAt,
    this.completedAt,
    this.currentSession,
    this.lastValidationFailureReasons = const [],
    this.lastValidationExplanation,
    this.replacementMissionInstanceId,
  });

  final MissionInstance instance;

  /// Full ordered history — the source the timeline UI reads from. Never
  /// exposes idempotency keys or raw error internals itself; that
  /// filtering happens at the presentation boundary (`MissionTimeline`).
  final List<MissionEvent> events;

  final MissionLifecycleState lifecycleState;
  final MissionProgressState progressState;
  final MissionRewardState rewardState;

  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? lastActivityAt;
  final DateTime? completedAt;

  final Duration totalActiveDuration;
  final Duration totalPausedDuration;
  final MissionSession? currentSession;
  final List<MissionSession> sessionHistory;

  final List<String> lastValidationFailureReasons;
  final String? lastValidationExplanation;

  final int pendingSyncCount;
  final String? replacementMissionInstanceId;

  bool get canView => lifecycleState == MissionLifecycleState.assigned;
  bool get canAccept =>
      lifecycleState == MissionLifecycleState.assigned ||
      lifecycleState == MissionLifecycleState.viewed;
  bool get canStart => lifecycleState == MissionLifecycleState.accepted;
  bool get canPause => lifecycleState == MissionLifecycleState.active;
  bool get canResume =>
      lifecycleState == MissionLifecycleState.paused ||
      lifecycleState == MissionLifecycleState.validationFailed;
  bool get canUpdateProgress =>
      lifecycleState == MissionLifecycleState.active ||
      lifecycleState == MissionLifecycleState.paused;
  bool get canSubmit =>
      lifecycleState == MissionLifecycleState.active ||
      lifecycleState == MissionLifecycleState.paused;
  bool get canAbandon =>
      MissionLifecycleTransitions.nextState(
        lifecycleState,
        MissionEventType.abandoned,
      ) !=
      null;
  bool get canReject =>
      MissionLifecycleTransitions.nextState(
        lifecycleState,
        MissionEventType.rejected,
      ) !=
      null;

  /// Undo is further time/server-window-gated by the use case — this is
  /// only the *lifecycle* half of the check (see spec section 14).
  bool get canUndoCompletion =>
      lifecycleState == MissionLifecycleState.completed &&
      rewardState != MissionRewardState.confirmed;

  factory MissionAggregate.rehydrate(
    MissionInstance instance,
    List<MissionEvent> events,
  ) {
    final sorted = [...events]
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

    var lifecycle = MissionLifecycleState.assigned;
    var progress = MissionProgressState.initial(instance.progressDefinition);
    var reward = MissionRewardState.none;
    DateTime? acceptedAt;
    DateTime? startedAt;
    DateTime? completedAt;
    DateTime? lastActivityAt;
    var validationReasons = const <String>[];
    String? validationExplanation;
    String? replacementId;
    var pendingSync = 0;
    var sawAssigned = false;

    for (final event in sorted) {
      lastActivityAt = event.occurredAt;

      final MissionLifecycleState? next;
      if (event.type == MissionEventType.assigned) {
        next = MissionLifecycleTransitions.canAssign(!sawAssigned)
            ? MissionLifecycleState.assigned
            : null;
        sawAssigned = true;
      } else {
        next = MissionLifecycleTransitions.nextState(lifecycle, event.type);
      }
      // An event that can't legally apply from the current state is
      // skipped defensively during replay — the append-time use case is
      // what actually prevents this from ever being written in the first
      // place (see MissionEventRepository.append).
      if (next == null) continue;
      lifecycle = next;

      switch (event) {
        case MissionAccepted():
          acceptedAt = event.occurredAt;
        case MissionStarted():
          startedAt ??= event.occurredAt;
        case MissionProgressUpdated(progress: final updatedProgress):
          progress = updatedProgress;
        case MissionValidationFailed(
          :final reasonCodes,
          :final userFacingExplanation,
        ):
          validationReasons = reasonCodes;
          validationExplanation = userFacingExplanation;
        case MissionValidationPassed():
          validationReasons = const [];
          validationExplanation = null;
        case MissionCompleted():
          completedAt = event.occurredAt;
          reward = MissionRewardState.pendingServerConfirmation;
        case MissionCompletionUndone():
          completedAt = null;
          reward = MissionRewardState.none;
        case MissionRejected(:final replacementMissionInstanceId):
          replacementId = replacementMissionInstanceId;
        case MissionSyncQueued():
          pendingSync += 1;
        case MissionSyncConfirmed():
          pendingSync = pendingSync > 0 ? pendingSync - 1 : 0;
        case MissionSyncFailed():
          break; // stays counted as pending until retried/confirmed.
        default:
          break;
      }
    }

    final sessionReduction = MissionSessionReducer.reduce(sorted);

    return MissionAggregate(
      instance: instance,
      events: sorted,
      lifecycleState: lifecycle,
      progressState: progress,
      rewardState: reward,
      acceptedAt: acceptedAt,
      startedAt: startedAt,
      completedAt: completedAt,
      lastActivityAt: lastActivityAt,
      totalActiveDuration: sessionReduction.totalActiveDuration,
      totalPausedDuration: sessionReduction.totalPausedDuration,
      currentSession: sessionReduction.currentSession,
      sessionHistory: sessionReduction.sessionHistory,
      lastValidationFailureReasons: validationReasons,
      lastValidationExplanation: validationExplanation,
      pendingSyncCount: pendingSync,
      replacementMissionInstanceId: replacementId,
    );
  }
}
