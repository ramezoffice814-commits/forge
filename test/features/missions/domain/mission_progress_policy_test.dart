import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_definition.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_policy.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_state.dart';

void main() {
  group('numeric progress (counter/quantity/hydration/percentage)', () {
    test('an increase is accepted and normalized', () {
      final result = MissionProgressPolicy.evaluate(
        current: const CounterProgressState(currentCount: 2, targetCount: 10),
        proposed: const CounterProgressState(currentCount: 5, targetCount: 10),
      );
      expect(result.isAccepted, isTrue);
      expect((result.normalizedState as CounterProgressState).currentCount, 5);
    });

    test('a decrease without isCorrection is rejected', () {
      final result = MissionProgressPolicy.evaluate(
        current: const CounterProgressState(currentCount: 5, targetCount: 10),
        proposed: const CounterProgressState(currentCount: 2, targetCount: 10),
      );
      expect(result.isAccepted, isFalse);
      expect(result.reasonCodes, contains('decreaseRequiresCorrection'));
      // Rejections normalize back to the current value, not the proposal.
      expect((result.normalizedState as CounterProgressState).currentCount, 5);
    });

    test('a decrease with isCorrection=true is accepted', () {
      final result = MissionProgressPolicy.evaluate(
        current: const CounterProgressState(currentCount: 5, targetCount: 10),
        proposed: const CounterProgressState(currentCount: 2, targetCount: 10),
        isCorrection: true,
      );
      expect(result.isAccepted, isTrue);
      expect((result.normalizedState as CounterProgressState).currentCount, 2);
    });

    test('a value above the policy max is clamped down', () {
      final result = MissionProgressPolicy.evaluate(
        current: const CounterProgressState(currentCount: 0, targetCount: 10),
        proposed: const CounterProgressState(
          currentCount: 999999,
          targetCount: 10,
        ),
      );
      expect(result.isAccepted, isTrue);
      expect(
        (result.normalizedState as CounterProgressState).currentCount,
        MissionProgressPolicy.maxCounterValue,
      );
    });

    test('hydration servings round-trip through the same numeric rule', () {
      final result = MissionProgressPolicy.evaluate(
        current: const HydrationProgressState(
          currentServings: 1,
          targetServings: 8,
        ),
        proposed: const HydrationProgressState(
          currentServings: 3,
          targetServings: 8,
        ),
      );
      expect(result.isAccepted, isTrue);
      expect(
        (result.normalizedState as HydrationProgressState).currentServings,
        3,
      );
    });

    test('percentage stays a double after normalization', () {
      final result = MissionProgressPolicy.evaluate(
        current: const PercentageProgressState(
          percentage: 10,
          thresholdPercentage: 100,
        ),
        proposed: const PercentageProgressState(
          percentage: 55.5,
          thresholdPercentage: 100,
        ),
      );
      expect(result.isAccepted, isTrue);
      expect(
        (result.normalizedState as PercentageProgressState).percentage,
        55.5,
      );
    });
  });

  group('duration progress (timer/reading)', () {
    test('an increase within the trusted interval is accepted', () {
      final result = MissionProgressPolicy.evaluate(
        current: const TimerProgressState(
          accumulatedDuration: Duration(minutes: 2),
          targetDuration: Duration(minutes: 10),
        ),
        proposed: const TimerProgressState(
          accumulatedDuration: Duration(minutes: 5),
          targetDuration: Duration(minutes: 10),
        ),
      );
      expect(result.isAccepted, isTrue);
    });

    test('a jump beyond the max trusted interval is rejected', () {
      final result = MissionProgressPolicy.evaluate(
        current: const TimerProgressState(
          accumulatedDuration: Duration(minutes: 2),
          targetDuration: Duration(minutes: 10),
        ),
        proposed: const TimerProgressState(
          accumulatedDuration: Duration(hours: 5),
          targetDuration: Duration(minutes: 10),
        ),
      );
      expect(result.isAccepted, isFalse);
      expect(result.reasonCodes, contains('implausibleDurationJump'));
    });

    test('a duration decrease without isCorrection is rejected', () {
      final result = MissionProgressPolicy.evaluate(
        current: const ReadingProgressState(
          durationRead: Duration(minutes: 5),
          targetDuration: Duration(minutes: 20),
        ),
        proposed: const ReadingProgressState(
          durationRead: Duration(minutes: 1),
          targetDuration: Duration(minutes: 20),
        ),
      );
      expect(result.isAccepted, isFalse);
    });
  });

  group('checklist progress', () {
    const items = [
      ChecklistItemDefinition(id: 'a', label: 'Step A'),
      ChecklistItemDefinition(id: 'b', label: 'Step B'),
    ];

    test('toggling a known item is accepted', () {
      final result = MissionProgressPolicy.evaluate(
        current: const ChecklistProgressState(
          items: items,
          completedItemIds: {},
        ),
        proposed: const ChecklistProgressState(
          items: items,
          completedItemIds: {'a'},
        ),
      );
      expect(result.isAccepted, isTrue);
    });

    test('an unknown item id is rejected', () {
      final result = MissionProgressPolicy.evaluate(
        current: const ChecklistProgressState(
          items: items,
          completedItemIds: {},
        ),
        proposed: const ChecklistProgressState(
          items: items,
          completedItemIds: {'does-not-exist'},
        ),
      );
      expect(result.isAccepted, isFalse);
      expect(result.reasonCodes, contains('unknownChecklistItem'));
    });
  });

  group('reflection progress', () {
    test('a reflection update is always accepted regardless of length', () {
      final result = MissionProgressPolicy.evaluate(
        current: const ReflectionProgressState(
          minimumLength: 10,
          responseLength: 0,
          responsePresent: false,
        ),
        proposed: const ReflectionProgressState(
          minimumLength: 10,
          responseLength: 42,
          responsePresent: true,
        ),
      );
      expect(result.isAccepted, isTrue);
      expect(
        (result.normalizedState as ReflectionProgressState).responseLength,
        42,
      );
    });
  });

  test('a mismatched progress type is always rejected', () {
    final result = MissionProgressPolicy.evaluate(
      current: const CounterProgressState(currentCount: 0, targetCount: 10),
      proposed: const BinaryProgressState(completed: true),
    );
    expect(result.isAccepted, isFalse);
    expect(result.reasonCodes, contains('mismatchedProgressType'));
  });
}
