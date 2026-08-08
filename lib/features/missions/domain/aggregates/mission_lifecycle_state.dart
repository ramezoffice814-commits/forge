import '../events/mission_event_source.dart';

/// The mission's position in its lifecycle. Deliberately does *not*
/// include a separate `rewardPending` bucket — reward status is its own
/// orthogonal axis (see `MissionRewardState`), derived independently, so a
/// completed mission's lifecycle stays simply `completed` regardless of
/// whether its reward is still pending, confirmed, or (eventually)
/// rejected. Section 22's Dashboard mapping groups
/// `completed`/`rewardPending` into one visual bucket precisely because
/// they're two facets of the same underlying `completed` lifecycle state.
enum MissionLifecycleState {
  assigned,
  viewed,
  accepted,
  active,
  paused,
  submitted,
  validationFailed,
  completed,
  abandoned,
  expired,
}

extension MissionLifecycleStateX on MissionLifecycleState {
  bool get isTerminal =>
      this == MissionLifecycleState.completed ||
      this == MissionLifecycleState.abandoned ||
      this == MissionLifecycleState.expired;
}

/// The explicit, enumerable transition table (spec section 7). A `null`
/// result means the transition is invalid from that state — callers must
/// treat that as a rejection, never force it through.
abstract final class MissionLifecycleTransitions {
  static const _preActive = {
    MissionLifecycleState.assigned,
    MissionLifecycleState.viewed,
    MissionLifecycleState.accepted,
  };

  static const _abandonable = {
    MissionLifecycleState.assigned,
    MissionLifecycleState.viewed,
    MissionLifecycleState.accepted,
    MissionLifecycleState.active,
    MissionLifecycleState.paused,
    MissionLifecycleState.validationFailed,
  };

  /// Whether a `MissionAssigned` event is valid as the very first event in
  /// an otherwise-empty stream — the one transition that doesn't have a
  /// "from" lifecycle state, since nothing has happened yet.
  static bool canAssign(bool streamIsEmpty) => streamIsEmpty;

  static MissionLifecycleState? nextState(
    MissionLifecycleState from,
    MissionEventType eventType,
  ) {
    switch (eventType) {
      case MissionEventType.assigned:
        return null; // see canAssign — handled outside this table.
      case MissionEventType.viewed:
        return from == MissionLifecycleState.assigned
            ? MissionLifecycleState.viewed
            : null;
      case MissionEventType.accepted:
        return _preActive.contains(from) &&
                from != MissionLifecycleState.accepted
            ? MissionLifecycleState.accepted
            : null;
      case MissionEventType.started:
        return from == MissionLifecycleState.accepted
            ? MissionLifecycleState.active
            : null;
      case MissionEventType.progressUpdated:
        return (from == MissionLifecycleState.active ||
                from == MissionLifecycleState.paused)
            ? from
            : null;
      case MissionEventType.paused:
        return from == MissionLifecycleState.active
            ? MissionLifecycleState.paused
            : null;
      case MissionEventType.resumed:
        return (from == MissionLifecycleState.paused ||
                from == MissionLifecycleState.validationFailed)
            ? MissionLifecycleState.active
            : null;
      case MissionEventType.submitted:
        return (from == MissionLifecycleState.active ||
                from == MissionLifecycleState.paused)
            ? MissionLifecycleState.submitted
            : null;
      case MissionEventType.validationFailed:
        return from == MissionLifecycleState.submitted
            ? MissionLifecycleState.validationFailed
            : null;
      case MissionEventType.validationPassed:
        return from == MissionLifecycleState.submitted ? from : null;
      case MissionEventType.completed:
        return from == MissionLifecycleState.submitted
            ? MissionLifecycleState.completed
            : null;
      case MissionEventType.completionUndone:
        return from == MissionLifecycleState.completed
            ? MissionLifecycleState.active
            : null;
      case MissionEventType.rejected:
        return _preActive.contains(from)
            ? MissionLifecycleState.abandoned
            : null;
      case MissionEventType.easierRequested:
      case MissionEventType.categoryChangeRequested:
        return from; // informational only — no lifecycle change.
      case MissionEventType.abandoned:
        return _abandonable.contains(from)
            ? MissionLifecycleState.abandoned
            : null;
      case MissionEventType.expired:
        return from.isTerminal ? null : MissionLifecycleState.expired;
      case MissionEventType.syncQueued:
      case MissionEventType.syncConfirmed:
      case MissionEventType.syncFailed:
        return from; // sync status never changes the lifecycle bucket.
    }
  }
}
