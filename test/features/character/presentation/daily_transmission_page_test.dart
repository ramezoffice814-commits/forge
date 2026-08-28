import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/character/data/mock/fake_tts_service.dart';
import 'package:forge/features/character/data/transmission_repository_provider.dart';
import 'package:forge/features/character/presentation/daily_transmission_page.dart';
import 'package:forge/shared/widgets/forge_button.dart';

import '../../../support/character_test_harness.dart';

void main() {
  testWidgets('initial load reaches mission reveal with the Accept control '
      'enabled', (tester) async {
    final harness = TransmissionTestHarness();
    await tester.pumpWidget(harness.page());
    await tester.pumpAndSettle();

    expect(find.text('The Watcher'), findsOneWidget);
    expect(find.text("TODAY'S MISSION"), findsOneWidget);
    expect(find.widgetWithText(ForgeButton, 'Accept Mission'), findsOneWidget);
  });

  testWidgets('speaking state shows the current line as a subtitle', (
    tester,
  ) async {
    final harness = TransmissionTestHarness(
      tts: FakeTtsService(autoComplete: false),
    );
    await tester.pumpWidget(harness.page());
    await tester.pumpAndSettle();

    // Frozen mid-first-line: the subtitle panel must show line one, not a
    // later line or nothing.
    expect(find.textContaining('the current is ready'), findsOneWidget);
    expect(find.textContaining('1 /'), findsOneWidget);
  });

  testWidgets('mute button flips to unmute and stops audio immediately', (
    tester,
  ) async {
    final tts = FakeTtsService(autoComplete: false);
    final harness = TransmissionTestHarness(tts: tts);
    await tester.pumpWidget(harness.page());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(tts.stopCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('skip button jumps straight to mission reveal', (tester) async {
    final harness = TransmissionTestHarness(
      tts: FakeTtsService(autoComplete: false),
    );
    await tester.pumpWidget(harness.page());
    await tester.pumpAndSettle();

    // Still mid-speech (frozen by the stalled fake TTS): Accept Mission
    // stays visible (disabled states must be visible, not hidden) but is
    // disabled until the mission has actually been revealed.
    final beforeSkip = tester.widget<ForgeButton>(
      find.widgetWithText(ForgeButton, 'Accept Mission'),
    );
    expect(beforeSkip.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pumpAndSettle();

    expect(find.text("TODAY'S MISSION"), findsOneWidget);
    final acceptButton = tester.widget<ForgeButton>(
      find.widgetWithText(ForgeButton, 'Accept Mission'),
    );
    expect(acceptButton.onPressed, isNotNull);
  });

  testWidgets('replay restarts dialogue after reveal without crashing', (
    tester,
  ) async {
    final tts = FakeTtsService();
    final harness = TransmissionTestHarness(tts: tts);
    await tester.pumpWidget(harness.page());
    await tester.pumpAndSettle();

    final spokenBefore = tts.spokenTexts.length;
    await tester.tap(find.byIcon(Icons.replay_rounded));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tts.spokenTexts.length, spokenBefore * 2);
    expect(find.widgetWithText(ForgeButton, 'Accept Mission'), findsOneWidget);
  });

  testWidgets('transcript control opens and closes the full transcript', (
    tester,
  ) async {
    final harness = TransmissionTestHarness();
    await tester.pumpWidget(harness.page());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.subject_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('Transcript'), findsOneWidget);
    expect(find.textContaining('the current is ready'), findsWidgets);

    await tester.tap(find.widgetWithText(ForgeButton, 'Close'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Transcript'), findsNothing);
  });

  testWidgets('accepting the mission disables further acceptance', (
    tester,
  ) async {
    final harness = TransmissionTestHarness();
    await tester.pumpWidget(harness.page());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ForgeButton, 'Accept Mission'));
    await tester.pumpAndSettle();

    final acceptButton = tester.widget<ForgeButton>(
      find.widgetWithText(ForgeButton, 'Mission Accepted'),
    );
    expect(acceptButton.onPressed, isNull);
  });

  testWidgets('TTS unavailable shows a non-blocking notice; mission still '
      'reveals', (tester) async {
    final harness = TransmissionTestHarness(
      tts: FakeTtsService(simulateUnavailable: true),
    );
    await tester.pumpWidget(harness.page());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Voice unavailable on this device'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ForgeButton, 'Accept Mission'), findsOneWidget);
  });

  testWidgets('offline fallback shows a retry action, not a hard block', (
    tester,
  ) async {
    final harness = TransmissionTestHarness();
    await tester.pumpWidget(
      harness.page(scenario: TransmissionMockScenario.offline),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're offline"), findsOneWidget);
    expect(find.widgetWithText(ForgeButton, 'Retry'), findsOneWidget);
  });

  testWidgets('renders without overflow at a large text scale', (tester) async {
    final harness = TransmissionTestHarness();
    await tester.pumpWidget(harness.page(textScale: 2.5));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion still reaches mission reveal', (tester) async {
    final harness = TransmissionTestHarness();
    await tester.pumpWidget(harness.page(reducedMotion: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(ForgeButton, 'Accept Mission'), findsOneWidget);
  });

  testWidgets('essential controls carry semantic labels', (tester) async {
    final semantics = tester.ensureSemantics();
    final harness = TransmissionTestHarness();
    await tester.pumpWidget(harness.page());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Close transmission'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Line \d+ of \d+$')), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('leaving the transmission page stops audio and disposes '
      'cleanly', (tester) async {
    final tts = FakeTtsService(autoComplete: false);
    final harness = TransmissionTestHarness(tts: tts);

    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides(),
        child: MaterialApp(
          theme: ForgeTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ForgeButton(
                  label: 'Open',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DailyTransmissionPage(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ForgeButton, 'Open'));
    await tester.pumpAndSettle();
    expect(tts.spokenTexts, isNotEmpty);

    final stopsBeforeLeaving = tts.stopCalls;
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(DailyTransmissionPage), findsNothing);
    expect(tts.stopCalls, greaterThan(stopsBeforeLeaving));
  });
}
