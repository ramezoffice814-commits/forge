import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/character/domain/entities/character_id.dart';
import 'package:forge/features/character/domain/entities/transmission_script.dart';
import 'package:forge/features/character/presentation/widgets/mission_reveal_panel.dart';
import 'package:forge/features/dashboard/domain/entities/mission_preview.dart';

void main() {
  final script = TransmissionScript(
    id: 's',
    characterId: CharacterId.watcher,
    date: DateTime.utc(2026, 8, 5),
    introLabel: 'Incoming Transmission',
    dialogueLines: const [],
    missionTitle: '20 Push-ups',
    missionDescription: 'Three sets to failure.',
    category: 'Fitness',
    difficulty: MissionDifficulty.moderate,
    estimatedMinutes: 15,
    xpReward: 50,
    requiresProof: true,
    completionConditions: const ['Complete three sets'],
    accessibilitySummary: 'summary',
  );

  testWidgets('renders mission metadata, tags, and completion conditions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.dark(),
        home: Scaffold(body: MissionRevealPanel(script: script)),
      ),
    );

    expect(find.text('20 Push-ups'), findsOneWidget);
    expect(find.text('Three sets to failure.'), findsOneWidget);
    expect(find.text('+50 XP'), findsOneWidget);
    expect(find.text('Moderate'), findsOneWidget);
    expect(find.text('~15 min'), findsOneWidget);
    expect(find.text('Proof required'), findsOneWidget);
    expect(find.text('Complete three sets'), findsOneWidget);
  });
}
