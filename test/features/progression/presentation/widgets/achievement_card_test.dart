import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/progression/domain/entities/achievement_definition.dart';
import 'package:forge/features/progression/domain/entities/achievement_progress.dart';
import 'package:forge/features/progression/presentation/widgets/achievement_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ForgeTheme.dark(),
  home: Scaffold(body: child),
);

void main() {
  const visibleDefinition = AchievementDefinition(
    id: 'visible',
    name: 'Visible Achievement',
    description: 'A normal achievement.',
    category: AchievementCategory.consistency,
    criteria: TotalCompletionsCriteria(10),
    rarity: AchievementRarity.common,
    iconId: 'visible',
  );

  const hiddenDefinition = AchievementDefinition(
    id: 'hidden',
    name: 'Secret Achievement',
    description: 'A description that should never leak.',
    category: AchievementCategory.exploration,
    criteria: TotalCompletionsCriteria(10),
    rarity: AchievementRarity.epic,
    iconId: 'hidden',
    hiddenUntilUnlocked: true,
  );

  testWidgets('a locked achievement shows Locked and no progress bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AchievementCard(
          progress: AchievementProgress(
            definition: visibleDefinition,
            status: AchievementStatus.locked,
            current: 0,
            target: 10,
          ),
        ),
      ),
    );

    expect(find.text('Visible Achievement'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('a progressing achievement shows current/target and a bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AchievementCard(
          progress: AchievementProgress(
            definition: visibleDefinition,
            status: AchievementStatus.progressing,
            current: 3,
            target: 10,
          ),
        ),
      ),
    );

    expect(find.text('3 / 10'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('an unlocked achievement shows its rarity tag', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AchievementCard(
          progress: AchievementProgress(
            definition: visibleDefinition,
            status: AchievementStatus.unlocked,
            current: 10,
            target: 10,
          ),
        ),
      ),
    );

    expect(find.text('Common'), findsOneWidget);
  });

  testWidgets(
    'a hidden-until-unlocked achievement never reveals its real name or '
    'description while locked',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AchievementCard(
            progress: AchievementProgress(
              definition: hiddenDefinition,
              status: AchievementStatus.locked,
              current: 0,
              target: 10,
            ),
          ),
        ),
      );

      expect(find.text('Secret Achievement'), findsNothing);
      expect(find.textContaining('should never leak'), findsNothing);
      expect(find.text('Hidden Achievement'), findsOneWidget);
    },
  );

  testWidgets('a hidden achievement reveals its real name once unlocked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AchievementCard(
          progress: AchievementProgress(
            definition: hiddenDefinition,
            status: AchievementStatus.unlocked,
            current: 10,
            target: 10,
          ),
        ),
      ),
    );

    expect(find.text('Secret Achievement'), findsOneWidget);
  });
}
