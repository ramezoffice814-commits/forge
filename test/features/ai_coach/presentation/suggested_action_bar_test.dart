import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_coach_suggested_action.dart';
import 'package:forge/features/ai_coach/presentation/widgets/suggested_action_bar.dart';
import 'package:forge/features/missions/data/mock/mock_mission_context.dart';
import 'package:forge/features/missions/presentation/providers/mission_providers.dart';
import 'package:forge/features/missions/presentation/providers/mission_selection_controller.dart';
import 'package:forge/features/missions/presentation/providers/mission_selection_state.dart';

void main() {
  testWidgets(
    'a safe suggested action end-to-end: AI suggests, user confirms, the '
    'existing deterministic MissionSelectionController executes it — the '
    'AI never mutates mission state directly (Roadmap Item 14B section 12)',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          missionMockScenarioProvider.overrideWithValue(
            MockMissionContextScenario.categoryPreference,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(missionSelectionControllerProvider.notifier).ready;

      final before =
          (container.read(missionSelectionControllerProvider)
                  as MissionSelectionReady)
              .result
              .resolvedDifficulty;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ForgeTheme.dark(),
            home: const Scaffold(
              body: SuggestedActionBar(
                actions: [AiCoachSuggestedAction.requestEasierMission],
              ),
            ),
          ),
        ),
      );

      // The action is only ever proposed, never applied yet.
      expect(
        (container.read(missionSelectionControllerProvider)
                as MissionSelectionReady)
            .result
            .resolvedDifficulty,
        before,
      );

      await tester.tap(find.text('Try an easier mission?'));
      await tester.pumpAndSettle();

      // Confirmation step — the AI's suggestion alone must not be enough.
      expect(find.text('Switch to an easier mission?'), findsOneWidget);
      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();

      final after =
          (container.read(missionSelectionControllerProvider)
                  as MissionSelectionReady)
              .result
              .resolvedDifficulty;
      expect(
        after.index,
        lessThan(before.index),
        reason:
            'confirming must invoke the same deterministic '
            'MissionSelectionController.requestEasierMission() a user '
            'could already reach through ordinary Forge UI',
      );
    },
  );

  testWidgets(
    'declining the confirmation dialog leaves mission selection untouched',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          missionMockScenarioProvider.overrideWithValue(
            MockMissionContextScenario.categoryPreference,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(missionSelectionControllerProvider.notifier).ready;

      final before =
          (container.read(missionSelectionControllerProvider)
                  as MissionSelectionReady)
              .result
              .resolvedDifficulty;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ForgeTheme.dark(),
            home: const Scaffold(
              body: SuggestedActionBar(
                actions: [AiCoachSuggestedAction.requestEasierMission],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Try an easier mission?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        (container.read(missionSelectionControllerProvider)
                as MissionSelectionReady)
            .result
            .resolvedDifficulty,
        before,
      );
    },
  );

  testWidgets(
    'renders nothing for a suggested action this pass does not wire',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ForgeTheme.dark(),
            home: const Scaffold(
              body: SuggestedActionBar(
                actions: [AiCoachSuggestedAction.explainMission],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ActionChip), findsNothing);
    },
  );
}
