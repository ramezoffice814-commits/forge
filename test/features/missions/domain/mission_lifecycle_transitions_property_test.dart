import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/aggregates/mission_lifecycle_state.dart';
import 'package:forge/features/missions/domain/events/mission_event_source.dart';

/// Sweeps every (fromState x eventType) combination the transition table can
/// be asked about — 10 states x 19 event types = 190 combinations — rather
/// than hand-picking examples, to catch the kind of edge case that only
/// shows up on a full grid (this exact technique caught a real bug in
/// `MissionSafetyPolicy` during the mission-selection phase).
void main() {
  test('nextState never throws for any (state, eventType) combination', () {
    for (final from in MissionLifecycleState.values) {
      for (final eventType in MissionEventType.values) {
        expect(
          () => MissionLifecycleTransitions.nextState(from, eventType),
          returnsNormally,
          reason: '$from + $eventType',
        );
      }
    }
  });

  test('a terminal state never advances to a different lifecycle bucket '
      'except the informational/sync no-ops', () {
    const informationalOrSyncOnly = {
      MissionEventType.easierRequested,
      MissionEventType.categoryChangeRequested,
      MissionEventType.syncQueued,
      MissionEventType.syncConfirmed,
      MissionEventType.syncFailed,
    };

    for (final from in MissionLifecycleState.values) {
      if (!from.isTerminal) continue;
      for (final eventType in MissionEventType.values) {
        final next = MissionLifecycleTransitions.nextState(from, eventType);
        if (informationalOrSyncOnly.contains(eventType)) {
          expect(next, from, reason: '$from + $eventType');
        } else if (from == MissionLifecycleState.completed &&
            eventType == MissionEventType.completionUndone) {
          // The one deliberate exception: undoing a completion is exactly
          // what's supposed to move a "terminal" completed mission back to
          // active (see spec section 14).
          expect(
            next,
            MissionLifecycleState.active,
            reason: '$from + $eventType',
          );
        } else {
          expect(next, isNull, reason: '$from + $eventType');
        }
      }
    }
  });

  test('assigned only ever advances via viewed or accepted', () {
    for (final eventType in MissionEventType.values) {
      final next = MissionLifecycleTransitions.nextState(
        MissionLifecycleState.assigned,
        eventType,
      );
      if (next == null) continue;
      if (eventType == MissionEventType.viewed) {
        expect(next, MissionLifecycleState.viewed);
      } else if (eventType == MissionEventType.accepted) {
        expect(next, MissionLifecycleState.accepted);
      } else if (eventType == MissionEventType.rejected) {
        expect(next, MissionLifecycleState.abandoned);
      } else if (eventType == MissionEventType.abandoned) {
        expect(next, MissionLifecycleState.abandoned);
      } else if (eventType == MissionEventType.expired) {
        expect(next, MissionLifecycleState.expired);
      } else {
        // Informational/sync no-ops stay put.
        expect(next, MissionLifecycleState.assigned);
      }
    }
  });

  test('every non-terminal state has at least one legal way to become '
      'terminal (abandon or expire)', () {
    for (final from in MissionLifecycleState.values) {
      if (from.isTerminal) continue;
      final canAbandon =
          MissionLifecycleTransitions.nextState(
            from,
            MissionEventType.abandoned,
          ) !=
          null;
      final canExpire =
          MissionLifecycleTransitions.nextState(
            from,
            MissionEventType.expired,
          ) !=
          null;
      expect(
        canAbandon || canExpire,
        isTrue,
        reason: '$from has no way to reach a terminal state',
      );
    }
  });

  test('canAssign only ever permits assignment into an empty stream', () {
    expect(MissionLifecycleTransitions.canAssign(true), isTrue);
    expect(MissionLifecycleTransitions.canAssign(false), isFalse);
  });
}
