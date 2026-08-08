import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_definition.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_state.dart';
import 'package:forge/features/missions/presentation/widgets/progress_controls/checklist_progress_control.dart';
import 'package:forge/features/missions/presentation/widgets/progress_controls/counter_progress_control.dart';
import 'package:forge/features/missions/presentation/widgets/progress_controls/reflection_progress_control.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ForgeTheme.dark(),
    home: Scaffold(body: Material(child: child)),
  );
}

void main() {
  group('CounterProgressControl', () {
    testWidgets('tapping + reports an increment, not a correction', (
      tester,
    ) async {
      MissionProgressState? reported;
      bool? reportedCorrection;
      await tester.pumpWidget(
        _wrap(
          CounterProgressControl(
            state: const CounterProgressState(currentCount: 2, targetCount: 10),
            onUpdate: (proposed, {isCorrection = false}) {
              reported = proposed;
              reportedCorrection = isCorrection;
            },
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect((reported as CounterProgressState).currentCount, 3);
      expect(reportedCorrection, isFalse);
    });

    testWidgets('tapping - reports a correction', (tester) async {
      bool? reportedCorrection;
      await tester.pumpWidget(
        _wrap(
          CounterProgressControl(
            state: const CounterProgressState(currentCount: 2, targetCount: 10),
            onUpdate: (proposed, {isCorrection = false}) {
              reportedCorrection = isCorrection;
            },
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();

      expect(reportedCorrection, isTrue);
    });

    testWidgets('the decrement button is disabled at zero', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CounterProgressControl(
            state: const CounterProgressState(currentCount: 0, targetCount: 10),
            onUpdate: (_, {isCorrection = false}) {},
          ),
        ),
      );

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.remove_rounded),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('disabled entirely when enabled=false', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          CounterProgressControl(
            state: const CounterProgressState(currentCount: 2, targetCount: 10),
            enabled: false,
            onUpdate: (_, {isCorrection = false}) => called = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(called, isFalse);
    });
  });

  group('ChecklistProgressControl', () {
    const items = [
      ChecklistItemDefinition(id: 'a', label: 'Step A'),
      ChecklistItemDefinition(id: 'b', label: 'Step B'),
    ];

    testWidgets('tapping an unchecked item adds it to completedItemIds', (
      tester,
    ) async {
      MissionProgressState? reported;
      await tester.pumpWidget(
        _wrap(
          ChecklistProgressControl(
            state: const ChecklistProgressState(
              items: items,
              completedItemIds: {},
            ),
            onUpdate: (proposed, {isCorrection = false}) => reported = proposed,
          ),
        ),
      );

      await tester.tap(find.text('Step A'));
      await tester.pump();

      expect((reported as ChecklistProgressState).completedItemIds, {'a'});
    });

    testWidgets('tapping a checked item removes it', (tester) async {
      MissionProgressState? reported;
      await tester.pumpWidget(
        _wrap(
          ChecklistProgressControl(
            state: const ChecklistProgressState(
              items: items,
              completedItemIds: {'a'},
            ),
            onUpdate: (proposed, {isCorrection = false}) => reported = proposed,
          ),
        ),
      );

      await tester.tap(find.text('Step A'));
      await tester.pump();

      expect((reported as ChecklistProgressState).completedItemIds, isEmpty);
    });
  });

  group('ReflectionProgressControl', () {
    testWidgets(
      'saving reports only length/presence — never the typed text itself',
      (tester) async {
        MissionProgressState? reported;
        await tester.pumpWidget(
          _wrap(
            ReflectionProgressControl(
              state: const ReflectionProgressState(
                minimumLength: 10,
                responseLength: 0,
                responsePresent: false,
              ),
              onUpdate: (proposed, {isCorrection = false}) =>
                  reported = proposed,
            ),
          ),
        );

        const secretText = 'something private the user typed';
        await tester.enterText(find.byType(TextField), secretText);
        await tester.tap(find.text('Save reflection'));
        await tester.pump();

        final result = reported as ReflectionProgressState;
        expect(result.responsePresent, isTrue);
        expect(result.responseLength, secretText.length);
        // The privacy guarantee: nothing about the reported state should be
        // (or even could be, given the type) the actual text.
        expect(result.toString().contains(secretText), isFalse);
      },
    );

    testWidgets('an empty save reports responsePresent=false', (tester) async {
      MissionProgressState? reported;
      await tester.pumpWidget(
        _wrap(
          ReflectionProgressControl(
            state: const ReflectionProgressState(
              minimumLength: 10,
              responseLength: 0,
              responsePresent: false,
            ),
            onUpdate: (proposed, {isCorrection = false}) => reported = proposed,
          ),
        ),
      );

      await tester.tap(find.text('Save reflection'));
      await tester.pump();

      expect((reported as ReflectionProgressState).responsePresent, isFalse);
    });
  });
}
