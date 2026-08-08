import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/character/presentation/widgets/transmission_controls.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ForgeTheme.dark(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('disabled controls stay visible but do not respond to taps', (
    tester,
  ) async {
    var replayTaps = 0;
    var skipTaps = 0;

    await tester.pumpWidget(
      wrap(
        TransmissionControls(
          canReplay: false,
          canSkip: false,
          canAccept: false,
          muted: false,
          missionAccepted: false,
          onReplay: () => replayTaps++,
          onSkip: () => skipTaps++,
          onToggleMute: () {},
          onTranscript: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.replay_rounded));
    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pump();

    expect(replayTaps, 0);
    expect(skipTaps, 0);
  });

  testWidgets('enabled controls respond to taps exactly once each', (
    tester,
  ) async {
    var replayTaps = 0;
    var muteTaps = 0;
    var transcriptTaps = 0;

    await tester.pumpWidget(
      wrap(
        TransmissionControls(
          canReplay: true,
          canSkip: true,
          canAccept: true,
          muted: false,
          missionAccepted: false,
          onReplay: () => replayTaps++,
          onSkip: () {},
          onToggleMute: () => muteTaps++,
          onTranscript: () => transcriptTaps++,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.replay_rounded));
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.tap(find.byIcon(Icons.subject_rounded));
    await tester.pump();

    expect(replayTaps, 1);
    expect(muteTaps, 1);
    expect(transcriptTaps, 1);
  });

  testWidgets('mute icon reflects the muted flag', (tester) async {
    await tester.pumpWidget(
      wrap(
        TransmissionControls(
          canReplay: true,
          canSkip: true,
          canAccept: true,
          muted: true,
          missionAccepted: false,
          onReplay: () {},
          onSkip: () {},
          onToggleMute: () {},
          onTranscript: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
  });

  testWidgets('AcceptMissionButton disabled until canAccept, label reflects '
      'acceptance', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      wrap(
        AcceptMissionButton(
          canAccept: false,
          missionAccepted: false,
          onAccept: () => tapped++,
        ),
      ),
    );
    expect(find.text('Accept Mission'), findsOneWidget);
    await tester.tap(find.text('Accept Mission'));
    await tester.pump();
    expect(tapped, 0);

    await tester.pumpWidget(
      wrap(
        AcceptMissionButton(
          canAccept: true,
          missionAccepted: true,
          onAccept: () => tapped++,
        ),
      ),
    );
    expect(find.text('Mission Accepted'), findsOneWidget);
  });
}
