import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/dashboard/domain/entities/mission_preview.dart';
import 'package:forge/features/dashboard/presentation/mission_action_label.dart';

void main() {
  final expectedLabels = {
    MissionStatus.notStarted: 'View Mission',
    MissionStatus.viewed: 'Accept Mission',
    MissionStatus.accepted: 'Continue Mission',
    MissionStatus.readyToSubmit: 'Submit Completion',
    MissionStatus.completed: 'Completed',
    MissionStatus.unavailableOffline: 'Unavailable Offline',
  };

  for (final entry in expectedLabels.entries) {
    test('${entry.key} maps to "${entry.value}"', () {
      expect(missionActionLabel(entry.key), entry.value);
    });
  }

  test('only completed and unavailableOffline are non-actionable', () {
    for (final status in MissionStatus.values) {
      final expectedEnabled =
          status != MissionStatus.completed &&
          status != MissionStatus.unavailableOffline;
      expect(
        isMissionActionEnabled(status),
        expectedEnabled,
        reason: status.name,
      );
    }
  });
}
