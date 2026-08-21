import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/mission_progress_payload_mapper.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_definition.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_state.dart';

void main() {
  test('binary maps completed', () {
    final payload = mapMissionProgressToPayload(
      const BinaryProgressState(completed: true),
    );
    expect(payload.progressType, 'binary');
    expect(payload.progress, {'completed': true});
  });

  test('counter maps currentCount/targetCount', () {
    final payload = mapMissionProgressToPayload(
      const CounterProgressState(currentCount: 8, targetCount: 10),
    );
    expect(payload.progressType, 'counter');
    expect(payload.progress, {'currentCount': 8, 'targetCount': 10});
  });

  test('timer maps durations to whole seconds', () {
    final payload = mapMissionProgressToPayload(
      const TimerProgressState(
        accumulatedDuration: Duration(minutes: 2),
        targetDuration: Duration(minutes: 5),
      ),
    );
    expect(payload.progressType, 'timer');
    expect(payload.progress, {'accumulatedSeconds': 120, 'targetSeconds': 300});
  });

  test('checklist maps item ids and completed ids', () {
    final payload = mapMissionProgressToPayload(
      ChecklistProgressState(
        items: const [
          ChecklistItemDefinition(id: 'a', label: 'A'),
          ChecklistItemDefinition(id: 'b', label: 'B'),
        ],
        completedItemIds: const {'a'},
      ),
    );
    expect(payload.progressType, 'checklist');
    expect(payload.progress['itemIds'], ['a', 'b']);
    expect(payload.progress['completedItemIds'], ['a']);
  });

  test('reflection maps response fields', () {
    final payload = mapMissionProgressToPayload(
      const ReflectionProgressState(
        minimumLength: 50,
        responseLength: 60,
        responsePresent: true,
      ),
    );
    expect(payload.progressType, 'reflection');
    expect(payload.progress, {
      'responseLength': 60,
      'responsePresent': true,
      'minimumLength': 50,
    });
  });

  test('toCommandFields nests under progressType/progress keys', () {
    final payload = mapMissionProgressToPayload(
      const BinaryProgressState(completed: false),
    );
    final fields = payload.toCommandFields();
    expect(fields['progressType'], 'binary');
    expect(fields['progress'], {'completed': false});
  });
}
