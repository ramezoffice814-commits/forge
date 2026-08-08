import '../domain/entities/mission_preview.dart';

/// Maps a mission's status to the dashboard's primary-action label. Pure
/// and standalone so it's unit-testable without a widget tree.
String missionActionLabel(MissionStatus status) {
  return switch (status) {
    MissionStatus.notStarted => 'View Mission',
    MissionStatus.viewed => 'Accept Mission',
    MissionStatus.accepted => 'Continue Mission',
    MissionStatus.readyToSubmit => 'Submit Completion',
    MissionStatus.completed => 'Completed',
    MissionStatus.unavailableOffline => 'Unavailable Offline',
  };
}

/// Only `completed` and `unavailableOffline` are non-actionable — every
/// other status still has a real (if not-yet-implemented) next step.
bool isMissionActionEnabled(MissionStatus status) {
  return status != MissionStatus.completed &&
      status != MissionStatus.unavailableOffline;
}
