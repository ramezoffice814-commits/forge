import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_definition.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_state.dart';
import 'package:forge/features/missions/domain/validation/mission_completion_validator.dart';

void main() {
  const checklistItems = [
    ChecklistItemDefinition(id: 'a', label: 'A'),
    ChecklistItemDefinition(id: 'b', label: 'B'),
  ];

  // One (incomplete, complete) pair per progress type — a property-style
  // sweep verifying the same two invariants hold across every type: the
  // validator never passes an initial/incomplete state, and always passes
  // once the definition's own completion condition is met, and never
  // returns something other than "provisional".
  final cases =
      <
        String,
        (MissionProgressState incomplete, MissionProgressState complete)
      >{
        'binary': (
          const BinaryProgressState(completed: false),
          const BinaryProgressState(completed: true),
        ),
        'counter': (
          const CounterProgressState(currentCount: 2, targetCount: 10),
          const CounterProgressState(currentCount: 10, targetCount: 10),
        ),
        'timer': (
          const TimerProgressState(
            accumulatedDuration: Duration(minutes: 2),
            targetDuration: Duration(minutes: 10),
          ),
          const TimerProgressState(
            accumulatedDuration: Duration(minutes: 10),
            targetDuration: Duration(minutes: 10),
          ),
        ),
        'checklist': (
          const ChecklistProgressState(
            items: checklistItems,
            completedItemIds: {'a'},
          ),
          const ChecklistProgressState(
            items: checklistItems,
            completedItemIds: {'a', 'b'},
          ),
        ),
        'percentage': (
          const PercentageProgressState(
            percentage: 40,
            thresholdPercentage: 100,
          ),
          const PercentageProgressState(
            percentage: 100,
            thresholdPercentage: 100,
          ),
        ),
        'quantity': (
          const QuantityProgressState(currentValue: 1, targetValue: 8),
          const QuantityProgressState(currentValue: 8, targetValue: 8),
        ),
        'reflection': (
          const ReflectionProgressState(
            minimumLength: 10,
            responseLength: 2,
            responsePresent: true,
          ),
          const ReflectionProgressState(
            minimumLength: 10,
            responseLength: 20,
            responsePresent: true,
          ),
        ),
        'reading': (
          const ReadingProgressState(
            durationRead: Duration(minutes: 1),
            targetDuration: Duration(minutes: 5),
          ),
          const ReadingProgressState(
            durationRead: Duration(minutes: 5),
            targetDuration: Duration(minutes: 5),
          ),
        ),
        'codingSession': (
          const CodingSessionProgressState(
            accumulatedActiveDuration: Duration(minutes: 5),
            targetDuration: Duration(minutes: 25),
            checklist: checklistItems,
            completedItemIds: {'a'},
          ),
          const CodingSessionProgressState(
            accumulatedActiveDuration: Duration(minutes: 25),
            targetDuration: Duration(minutes: 25),
            checklist: checklistItems,
            completedItemIds: {'a', 'b'},
          ),
        ),
        'hydration': (
          const HydrationProgressState(currentServings: 1, targetServings: 8),
          const HydrationProgressState(currentServings: 8, targetServings: 8),
        ),
      };

  for (final entry in cases.entries) {
    final (incomplete, complete) = entry.value;
    test(
      '${entry.key}: incomplete progress fails validation, provisionally',
      () {
        final result = MissionCompletionValidator.validate(incomplete);
        expect(result.passed, isFalse, reason: entry.key);
        expect(result.provisionalOnly, isTrue, reason: entry.key);
        expect(result.reasonCodes, isNotEmpty, reason: entry.key);
      },
    );

    test(
      '${entry.key}: meeting the target passes validation, provisionally',
      () {
        final result = MissionCompletionValidator.validate(complete);
        expect(result.passed, isTrue, reason: entry.key);
        expect(result.provisionalOnly, isTrue, reason: entry.key);
        expect(result.reasonCodes, isEmpty, reason: entry.key);
      },
    );
  }

  test('every MissionProgressState.initial() value fails validation', () {
    final definitions = <MissionProgressDefinition>[
      const BinaryProgressDefinition(),
      const CounterProgressDefinition(targetCount: 10),
      const TimerProgressDefinition(targetDuration: Duration(minutes: 10)),
      const ChecklistProgressDefinition(items: checklistItems),
      const PercentageProgressDefinition(),
      const QuantityProgressDefinition(targetValue: 8),
      const ReflectionProgressDefinition(),
      const ReadingProgressDefinition(targetDuration: Duration(minutes: 5)),
      const CodingSessionProgressDefinition(
        targetDuration: Duration(minutes: 25),
        checklist: checklistItems,
      ),
      const HydrationProgressDefinition(targetServings: 8),
    ];

    for (final definition in definitions) {
      final initial = MissionProgressState.initial(definition);
      final result = MissionCompletionValidator.validate(initial);
      expect(result.passed, isFalse, reason: definition.type.name);
    }
  });
}
