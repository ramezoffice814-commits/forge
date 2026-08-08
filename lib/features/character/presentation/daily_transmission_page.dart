import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_tokens.dart';
import '../../../shared/widgets/forge_button.dart';
import '../../../shared/widgets/forge_loading_state.dart';
import '../../../shared/widgets/forge_scaffold.dart';
import '../domain/entities/character_profile.dart';
import 'controllers/daily_transmission_controller.dart';
import 'controllers/daily_transmission_state.dart';
import 'controllers/subtitle_sequencer.dart';
import 'widgets/dialogue_subtitle_panel.dart';
import 'widgets/forge_character_view.dart';
import 'widgets/mission_reveal_panel.dart';
import 'widgets/transcript_sheet.dart';
import 'widgets/transmission_controls.dart';
import 'widgets/transmission_status_header.dart';

/// The full-screen Daily Transmission experience, pushed from the
/// Dashboard. A dedicated page (rather than an inline Dashboard panel) so
/// the character gets real cinematic space, the system/browser back
/// gesture works without any custom interception, and this route's own
/// [AutoDisposeNotifierProvider]-backed controller tears itself down
/// (stopping TTS and animation) the moment the route is popped.
class DailyTransmissionPage extends ConsumerStatefulWidget {
  const DailyTransmissionPage({super.key});

  @override
  ConsumerState<DailyTransmissionPage> createState() =>
      _DailyTransmissionPageState();
}

class _DailyTransmissionPageState extends ConsumerState<DailyTransmissionPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      ref
          .read(dailyTransmissionControllerProvider.notifier)
          .handleAppBackgrounded();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    // Deferred to a microtask: this fires during the widget's build phase
    // and a Notifier must not have its state mutated while the tree is
    // still building.
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(dailyTransmissionControllerProvider.notifier)
          .setReducedMotion(reducedMotion);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyTransmissionControllerProvider);
    final notifier = ref.read(dailyTransmissionControllerProvider.notifier);
    const profile = CharacterProfile.watcher;

    return ForgeScaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TransmissionStatusHeader(
              profile: profile,
              phase: state.phase,
              onClose: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: _TransmissionBody(state: state, notifier: notifier),
          ),
        ],
      ),
    );
  }
}

class _TransmissionBody extends StatelessWidget {
  const _TransmissionBody({required this.state, required this.notifier});

  final DailyTransmissionState state;
  final DailyTransmissionController notifier;

  @override
  Widget build(BuildContext context) {
    if (state.phase == TransmissionPhase.error) {
      return _TransmissionErrorView(state: state, onRetry: notifier.retry);
    }
    if (state.script == null) {
      return const ForgeLoadingState(message: 'Connecting to the Forge…');
    }
    return _TransmissionContent(state: state, notifier: notifier);
  }
}

class _TransmissionContent extends StatelessWidget {
  const _TransmissionContent({required this.state, required this.notifier});

  final DailyTransmissionState state;
  final DailyTransmissionController notifier;

  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final script = state.script!;
    const profile = CharacterProfile.watcher;
    final sequencer = SubtitleSequencer(script.dialogueLines);
    final speakingIntensity = state.phase == TransmissionPhase.speaking
        ? 0.7
        : 0.0;

    final characterView = ForgeCharacterView(
      profile: profile,
      state: state.characterState,
      reducedMotion: state.reducedMotion,
      speakingIntensity: speakingIntensity,
    );

    final infoColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.dialogueIndex >= 0)
          DialogueSubtitlePanel(
            characterName: profile.displayName,
            line: sequencer.lineAt(state.dialogueIndex),
            lineNumber: (state.dialogueIndex + 1).clamp(
              1,
              script.dialogueLines.length,
            ),
            totalLines: script.dialogueLines.length,
            ttsUnavailableNotice: !state.ttsAvailable,
          ),
        if (state.hasReveal) ...[
          SizedBox(height: tokens.spacing.space4),
          MissionRevealPanel(script: script),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(tokens.spacing.space4),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: characterView,
                            ),
                          ),
                          SizedBox(width: tokens.spacing.space4),
                          Expanded(flex: 3, child: infoColumn),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Center(child: characterView),
                          ),
                          SizedBox(height: tokens.spacing.space4),
                          infoColumn,
                        ],
                      ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.space4,
                0,
                tokens.spacing.space4,
                tokens.spacing.space4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TransmissionControls(
                    canReplay: state.canReplay,
                    canSkip: state.canSkip,
                    canAccept: state.canAccept,
                    muted: state.muted,
                    missionAccepted: state.missionAccepted,
                    onReplay: notifier.replay,
                    onSkip: notifier.skip,
                    onToggleMute: notifier.toggleMute,
                    onTranscript: () => showTranscriptSheet(
                      context,
                      characterName: profile.displayName,
                      transcript: sequencer.transcript,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.space2),
                  AcceptMissionButton(
                    canAccept: state.canAccept,
                    missionAccepted: state.missionAccepted,
                    onAccept: notifier.acceptMission,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TransmissionErrorView extends StatelessWidget {
  const _TransmissionErrorView({required this.state, required this.onRetry});

  final DailyTransmissionState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.offlineFallback
                  ? Icons.cloud_off_rounded
                  : Icons.error_outline_rounded,
              size: 40,
              color: tokens.text.withValues(alpha: 0.5),
            ),
            SizedBox(height: tokens.spacing.space3),
            Text(
              state.offlineFallback ? "You're offline" : 'Transmission failed',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.spacing.space2),
            Text(
              state.errorMessage ??
                  "Today's mission couldn't be reached right now.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: tokens.spacing.space4),
            ForgeButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
