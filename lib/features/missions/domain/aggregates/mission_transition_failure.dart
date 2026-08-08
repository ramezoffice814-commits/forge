import '../events/mission_event_source.dart';
import 'mission_lifecycle_state.dart';

enum TransitionFailureReason {
  invalidTransition,
  missionExpired,
  missionAbandoned,
  missionAlreadyCompleted,
  rewardAlreadyConfirmed,
  outsideUndoWindow,
  laterConflictingEvent,
  duplicateEvent,
  malformedEvent,
}

/// A rejected action, with a concise message a UI can show directly (spec
/// section 29: prefer "Start the mission before pausing." over a generic
/// failure banner).
class MissionTransitionFailure {
  const MissionTransitionFailure({
    required this.reason,
    required this.message,
    required this.currentState,
    required this.attemptedEvent,
  });

  final TransitionFailureReason reason;
  final String message;
  final MissionLifecycleState currentState;
  final MissionEventType attemptedEvent;

  @override
  String toString() => 'MissionTransitionFailure($reason: $message)';
}
