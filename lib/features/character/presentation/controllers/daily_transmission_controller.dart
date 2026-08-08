import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/presentation/dashboard_notifier.dart';
import '../../../dashboard/presentation/dashboard_state.dart';
import '../../../missions/presentation/providers/mission_instance_provider.dart';
import '../../../missions/presentation/providers/mission_lifecycle_controller.dart';
import '../../../missions/presentation/providers/mission_selection_controller.dart';
import '../../data/services/placeholder_character_animation_controller.dart';
import '../../data/transmission_repository_provider.dart';
import '../../data/tts_service_provider.dart';
import '../../domain/entities/character_state.dart';
import '../../domain/repositories/transmission_repository.dart';
import '../../domain/services/character_animation_controller.dart';
import '../../domain/services/tts_service.dart';
import '../../domain/usecases/get_daily_transmission_usecase.dart';
import 'daily_transmission_state.dart';
import 'subtitle_sequencer.dart';

final getDailyTransmissionUseCaseProvider = Provider((ref) {
  return GetDailyTransmissionUseCase(ref.watch(transmissionRepositoryProvider));
});

/// Indirection so tests can swap in an instant-resolving fake — the real
/// [PlaceholderCharacterAnimationController]'s short one-shot delays are
/// fine for the real app but add unnecessary real time to a large test
/// suite.
final characterAnimationControllerFactoryProvider =
    Provider<CharacterAnimationController Function()>((ref) {
      return PlaceholderCharacterAnimationController.new;
    });

/// Drives the entire Daily Transmission presentation: fetching the script,
/// coordinating the character engine, TTS, and subtitle pacing, and
/// reacting to replay/skip/mute/accept. Every async gap is guarded by a
/// generation counter so a rapid sequence of user actions (or the provider
/// being disposed) can never let a stale continuation clobber a newer
/// state — this is what makes replay/skip/mute race-free and makes leaving
/// the screen stop playback immediately.
class DailyTransmissionController
    extends AutoDisposeNotifier<DailyTransmissionState> {
  late final TtsService _tts;
  late final CharacterAnimationController _characterEngine;
  int _generation = 0;

  @override
  DailyTransmissionState build() {
    _tts = ref.watch(ttsServiceProvider);
    _characterEngine = ref.watch(characterAnimationControllerFactoryProvider)();
    ref.onDispose(_onDispose);
    // `start()` reads/writes `state` as its very first action, which
    // Riverpod forbids before `build()` has returned and the initial state
    // is recorded — deferring to a microtask lets that happen first.
    Future.microtask(start);
    return const DailyTransmissionState();
  }

  void _onDispose() {
    _generation++;
    unawaited(_tts.stop());
    _characterEngine.dispose();
  }

  bool _stale(int generation) => generation != _generation;

  /// Called from the widget layer (every build is fine — it's a no-op once
  /// the value settles) so timing decisions never live inside a widget.
  void setReducedMotion(bool value) {
    if (state.reducedMotion == value) return;
    state = state.copyWith(reducedMotion: value);
  }

  Future<void> start() async {
    final generation = ++_generation;
    state = state.copyWith(
      phase: TransmissionPhase.preparing,
      errorMessage: null,
      offlineFallback: false,
    );

    final dashboardState = ref.read(dashboardNotifierProvider);
    if (dashboardState is! DashboardPopulated) {
      if (_stale(generation)) return;
      state = state.copyWith(
        phase: TransmissionPhase.error,
        errorMessage: "Your dashboard isn't ready yet.",
      );
      return;
    }

    await _tts.initialize();
    if (_stale(generation)) return;

    try {
      final script = await ref
          .read(getDailyTransmissionUseCaseProvider)
          .call(dashboardState.overview);
      if (_stale(generation)) return;
      state = state.copyWith(
        phase: TransmissionPhase.incoming,
        script: script,
        dialogueIndex: -1,
        ttsAvailable: _tts.isAvailable,
        characterState: CharacterState.incoming,
      );
    } on TransmissionOfflineException {
      if (_stale(generation)) return;
      state = state.copyWith(
        phase: TransmissionPhase.error,
        offlineFallback: true,
        errorMessage: "You're offline and nothing is cached for today.",
      );
      return;
    } catch (_) {
      if (_stale(generation)) return;
      state = state.copyWith(
        phase: TransmissionPhase.error,
        errorMessage: "Couldn't load today's transmission.",
      );
      return;
    }

    await _characterEngine.play(
      CharacterState.incoming,
      reducedMotion: state.reducedMotion,
    );
    if (_stale(generation)) return;
    await _enter(generation);
  }

  Future<void> retry() => start();

  Future<void> _enter(int generation) async {
    state = state.copyWith(
      phase: TransmissionPhase.entering,
      characterState: CharacterState.entering,
    );
    await _characterEngine.play(
      CharacterState.entering,
      reducedMotion: state.reducedMotion,
    );
    if (_stale(generation)) return;
    state = state.copyWith(phase: TransmissionPhase.speaking);
    await _speakFrom(0, generation);
  }

  Future<void> _speakFrom(int startIndex, int generation) async {
    final script = state.script;
    if (script == null) return;
    final sequencer = SubtitleSequencer(script.dialogueLines);
    if (sequencer.isEmpty) {
      await _revealMission(generation);
      return;
    }

    for (
      var i = startIndex;
      i <= sequencer.lastIndex;
      i = sequencer.nextIndex(i)
    ) {
      if (_stale(generation)) return;
      final line = sequencer.lineAt(i)!;
      final characterState = line.emotionalState ?? CharacterState.speaking;
      state = state.copyWith(dialogueIndex: i, characterState: characterState);
      await _characterEngine.play(
        characterState,
        reducedMotion: state.reducedMotion,
      );
      if (_stale(generation)) return;

      if (!state.muted && _tts.isAvailable) {
        try {
          await _tts.speak(line.text);
        } catch (_) {
          if (_stale(generation)) return;
          await _wait(line.estimatedDuration);
        }
      } else {
        await _wait(line.estimatedDuration);
      }
      if (_stale(generation)) return;

      if (line.pauseAfter > Duration.zero) {
        await _wait(line.pauseAfter);
        if (_stale(generation)) return;
      }
    }

    await _revealMission(generation);
  }

  Future<void> _wait(Duration duration) {
    if (duration <= Duration.zero) return Future.value();
    return Future<void>.delayed(duration);
  }

  Future<void> _revealMission(int generation) async {
    if (_stale(generation)) return;
    state = state.copyWith(
      phase: TransmissionPhase.missionReveal,
      characterState: CharacterState.missionRevealed,
    );
    await _characterEngine.play(
      CharacterState.missionRevealed,
      reducedMotion: state.reducedMotion,
    );
    if (_stale(generation)) return;
    state = state.copyWith(
      phase: TransmissionPhase.awaitingAcceptance,
      characterState: CharacterState.idle,
    );
    await _characterEngine.play(
      CharacterState.idle,
      reducedMotion: state.reducedMotion,
    );
  }

  /// Jumps straight to the mission reveal — safe from `incoming`,
  /// `entering`, or anywhere mid-speech. No-op once already revealed.
  void skip() {
    if (!state.canSkip) return;
    final script = state.script;
    if (script == null) return;
    final generation = ++_generation;
    unawaited(_tts.stop());
    _characterEngine.stop();
    state = state.copyWith(
      phase: TransmissionPhase.skipped,
      dialogueIndex: script.dialogueLines.length - 1,
    );
    unawaited(_revealMission(generation));
  }

  /// Restarts dialogue from the first line. Available any time after
  /// entering has completed. Rapid repeated taps are safe: each call bumps
  /// the generation counter, so only the last call's run is ever live.
  Future<void> replay() async {
    if (!state.canReplay) return;
    final generation = ++_generation;
    await _tts.stop();
    _characterEngine.stop();
    state = state.copyWith(
      phase: TransmissionPhase.replaying,
      dialogueIndex: -1,
      characterState: CharacterState.entering,
    );
    await _characterEngine.play(
      CharacterState.entering,
      reducedMotion: state.reducedMotion,
    );
    if (_stale(generation)) return;
    state = state.copyWith(phase: TransmissionPhase.speaking);
    await _speakFrom(0, generation);
  }

  /// Muting stops any in-flight speech immediately but never touches
  /// subtitle progression — the dialogue loop falls back to
  /// estimated-duration pacing while muted.
  Future<void> toggleMute() async {
    final muted = !state.muted;
    state = state.copyWith(muted: muted);
    if (muted) {
      await _tts.stop();
    }
  }

  Future<void> acceptMission() async {
    if (!state.canAccept) return;
    final generation = ++_generation;
    state = state.copyWith(
      phase: TransmissionPhase.accepting,
      characterState: CharacterState.missionAccepted,
    );
    await _characterEngine.play(
      CharacterState.missionAccepted,
      reducedMotion: state.reducedMotion,
    );
    if (_stale(generation)) return;

    // The event repository is the local source of truth for acceptance as
    // of the mission lifecycle phase — this is no longer presentation-only
    // state (see `MissionLifecycleController`/`AcceptMissionUseCase`). A
    // fixed idempotency key on `MissionAccepted` means accepting twice
    // (e.g. also from `ActiveMissionPage`) safely resolves to one event.
    // Awaiting `ready` mirrors `DashboardNotifier._load()`: reading
    // `missionInstanceProvider` before the selection controller's first
    // resolution lands would otherwise race and see `null`.
    await ref.read(missionSelectionControllerProvider.notifier).ready;
    if (_stale(generation)) return;
    final instance = ref.read(missionInstanceProvider);
    if (instance != null) {
      await ref
          .read(
            missionLifecycleControllerProvider(instance.instanceId).notifier,
          )
          .accept();
    }
    if (_stale(generation)) return;

    state = state.copyWith(
      phase: TransmissionPhase.accepted,
      missionAccepted: true,
      characterState: CharacterState.idle,
    );
  }

  /// The screen is no longer in the foreground (app backgrounded, or the
  /// OS reclaimed the surface) — stop any audio immediately. The dialogue
  /// loop, if still running, simply continues pacing subtitles silently;
  /// leaving the route entirely (which disposes this controller) is what
  /// fully tears playback down.
  Future<void> handleAppBackgrounded() => _tts.stop();
}

final dailyTransmissionControllerProvider =
    AutoDisposeNotifierProvider<
      DailyTransmissionController,
      DailyTransmissionState
    >(DailyTransmissionController.new);
