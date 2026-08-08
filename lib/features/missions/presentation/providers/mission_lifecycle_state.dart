import 'package:flutter/foundation.dart';

import '../../domain/aggregates/mission_aggregate.dart';
import '../../domain/aggregates/mission_transition_failure.dart';

/// Named `*ControllerState` (not `MissionLifecycleState`) to avoid colliding
/// with the domain's own `MissionLifecycleState` enum
/// (`assigned`/`active`/`completed`/...) — this is the *controller's*
/// loading/not-found/ready wrapper around that domain state.
@immutable
sealed class MissionLifecycleControllerState {
  const MissionLifecycleControllerState();
}

class MissionLifecycleLoading extends MissionLifecycleControllerState {
  const MissionLifecycleLoading();
}

/// The route was given a `missionInstanceId` that doesn't match today's
/// mission (e.g. a stale deep link, or the mission was replaced by a
/// rejection). Never a crash — always this state, which the page renders as
/// a safe error with a way back.
class MissionLifecycleNotFound extends MissionLifecycleControllerState {
  const MissionLifecycleNotFound(this.missionInstanceId);

  final String missionInstanceId;
}

class MissionLifecycleReady extends MissionLifecycleControllerState {
  const MissionLifecycleReady(this.aggregate, {this.lastFailure});

  final MissionAggregate aggregate;

  /// The most recent rejected action, if any — cleared explicitly by the UI
  /// once it's been shown, not by the next successful action, so a failed
  /// action's message never silently disappears before the user reads it.
  final MissionTransitionFailure? lastFailure;

  MissionLifecycleReady clearFailure() => MissionLifecycleReady(aggregate);
}
