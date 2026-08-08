import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/missions/domain/aggregates/mission_aggregate.dart';
import 'package:forge/features/missions/domain/aggregates/mission_lifecycle_state.dart';
import 'package:forge/features/missions/domain/aggregates/mission_reward_state.dart';
import 'package:forge/features/missions/domain/entities/mission_instance.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/missions/domain/enums/proof_policy.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_definition.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_state.dart';
import 'package:forge/features/missions/presentation/widgets/mission_action_bar.dart';
import 'package:forge/shared/widgets/forge_button.dart';

MissionAggregate _aggregate(MissionLifecycleState lifecycleState) {
  final instance = MissionInstance(
    instanceId: 'i1',
    definitionId: 'd1',
    assignedDate: DateTime.utc(2026, 8, 10),
    title: 'T',
    description: 'D',
    category: MissionCategory.fitness,
    resolvedDifficulty: MissionDifficultyLevel.easy,
    resolvedDuration: 5,
    xpHint: 10,
    completionConditions: const [],
    proofPolicy: ProofPolicy.none,
    selectionReasons: const [],
    engineVersion: '1.0.0',
    progressDefinition: const BinaryProgressDefinition(),
  );
  return MissionAggregate(
    instance: instance,
    events: const [],
    lifecycleState: lifecycleState,
    progressState: const BinaryProgressState(completed: false),
    rewardState: MissionRewardState.none,
    totalActiveDuration: Duration.zero,
    totalPausedDuration: Duration.zero,
    sessionHistory: const [],
    pendingSyncCount: 0,
  );
}

Widget _wrap(Widget child) => MaterialApp(
  theme: ForgeTheme.dark(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('an assigned mission shows Accept and Not today', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MissionActionBar(
          aggregate: _aggregate(MissionLifecycleState.assigned),
          onAccept: () {},
          onStart: () {},
          onPause: () {},
          onResume: () {},
          onSubmit: () {},
          onReject: (_) {},
          onAbandon: () {},
          onUndoCompletion: () {},
        ),
      ),
    );

    expect(find.widgetWithText(ForgeButton, 'Accept mission'), findsOneWidget);
    expect(find.widgetWithText(ForgeButton, 'Not today'), findsOneWidget);
    expect(find.widgetWithText(ForgeButton, 'Start'), findsNothing);
    expect(find.widgetWithText(ForgeButton, 'Submit'), findsNothing);
  });

  testWidgets('an active mission shows Pause, Submit, and Abandon', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MissionActionBar(
          aggregate: _aggregate(MissionLifecycleState.active),
          onAccept: () {},
          onStart: () {},
          onPause: () {},
          onResume: () {},
          onSubmit: () {},
          onReject: (_) {},
          onAbandon: () {},
          onUndoCompletion: () {},
        ),
      ),
    );

    expect(find.widgetWithText(ForgeButton, 'Pause'), findsOneWidget);
    expect(find.widgetWithText(ForgeButton, 'Submit'), findsOneWidget);
    expect(find.widgetWithText(ForgeButton, 'Abandon'), findsOneWidget);
    expect(find.widgetWithText(ForgeButton, 'Accept mission'), findsNothing);
  });

  testWidgets('a completed mission (reward not yet confirmed) shows Undo '
      'completion and nothing else actionable', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MissionActionBar(
          aggregate: _aggregate(MissionLifecycleState.completed),
          onAccept: () {},
          onStart: () {},
          onPause: () {},
          onResume: () {},
          onSubmit: () {},
          onReject: (_) {},
          onAbandon: () {},
          onUndoCompletion: () {},
        ),
      ),
    );

    expect(find.widgetWithText(ForgeButton, 'Undo completion'), findsOneWidget);
    expect(find.widgetWithText(ForgeButton, 'Submit'), findsNothing);
    expect(find.widgetWithText(ForgeButton, 'Abandon'), findsNothing);
  });

  testWidgets('tapping Accept mission invokes onAccept', (tester) async {
    var accepted = false;
    await tester.pumpWidget(
      _wrap(
        MissionActionBar(
          aggregate: _aggregate(MissionLifecycleState.assigned),
          onAccept: () => accepted = true,
          onStart: () {},
          onPause: () {},
          onResume: () {},
          onSubmit: () {},
          onReject: (_) {},
          onAbandon: () {},
          onUndoCompletion: () {},
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ForgeButton, 'Accept mission'));
    await tester.pump();
    expect(accepted, isTrue);
  });
}
