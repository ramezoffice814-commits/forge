import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/character/domain/entities/dialogue_line.dart';
import 'package:forge/features/character/presentation/widgets/dialogue_subtitle_panel.dart';

void main() {
  Widget wrap(Widget child, {double textScale = 1.0}) {
    return MaterialApp(
      theme: ForgeTheme.dark(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: child,
        ),
      ),
    );
  }

  const line = DialogueLine(
    id: 'l1',
    text: 'The forge is ready.',
    estimatedDuration: Duration(seconds: 1),
  );

  testWidgets('shows the full line at once — no typewriter reveal', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const DialogueSubtitlePanel(
          characterName: 'The Watcher',
          line: line,
          lineNumber: 1,
          totalLines: 3,
          ttsUnavailableNotice: false,
        ),
      ),
    );

    expect(find.text('The forge is ready.'), findsOneWidget);
    expect(find.textContaining('1 / 3'), findsOneWidget);
  });

  testWidgets('shows a non-blocking notice when TTS is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const DialogueSubtitlePanel(
          characterName: 'The Watcher',
          line: line,
          lineNumber: 1,
          totalLines: 1,
          ttsUnavailableNotice: true,
        ),
      ),
    );

    expect(
      find.textContaining('Voice unavailable on this device'),
      findsOneWidget,
    );
    // The line itself must still be fully visible alongside the notice.
    expect(find.text('The forge is ready.'), findsOneWidget);
  });

  testWidgets('renders without overflow at a large text scale', (tester) async {
    await tester.pumpWidget(
      wrap(
        const DialogueSubtitlePanel(
          characterName: 'The Watcher',
          line: line,
          lineNumber: 1,
          totalLines: 1,
          ttsUnavailableNotice: true,
        ),
        textScale: 2.5,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
