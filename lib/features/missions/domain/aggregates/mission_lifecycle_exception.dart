import 'mission_transition_failure.dart';

/// Thrown by a use case when the requested action isn't legal from the
/// aggregate's current state — callers (the controller) catch this and
/// surface [failure] rather than letting an invalid action silently no-op
/// or crash.
class MissionLifecycleException implements Exception {
  const MissionLifecycleException(this.failure);

  final MissionTransitionFailure failure;

  @override
  String toString() => 'MissionLifecycleException: ${failure.message}';
}
