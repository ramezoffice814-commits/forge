import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/character/data/mock/fake_character_animation_controller.dart';
import 'package:forge/features/character/data/mock/fake_tts_service.dart';
import 'package:forge/features/character/data/transmission_repository_provider.dart';
import 'package:forge/features/character/data/tts_service_provider.dart';
import 'package:forge/features/character/domain/entities/character_id.dart';
import 'package:forge/features/character/domain/entities/dialogue_line.dart';
import 'package:forge/features/character/domain/entities/transmission_script.dart';
import 'package:forge/features/character/domain/repositories/transmission_repository.dart';
import 'package:forge/features/character/domain/services/character_animation_controller.dart';
import 'package:forge/features/character/domain/services/tts_service.dart';
import 'package:forge/features/character/presentation/controllers/daily_transmission_controller.dart';
import 'package:forge/features/character/presentation/controllers/daily_transmission_state.dart';
import 'package:forge/features/dashboard/domain/entities/dashboard_overview.dart';
import 'package:forge/features/dashboard/domain/entities/mission_preview.dart'
    show MissionDifficulty;
import 'package:forge/features/missions/domain/aggregates/mission_lifecycle_state.dart'
    as lifecycle;
import 'package:forge/features/missions/presentation/providers/mission_instance_provider.dart';
import 'package:forge/features/missions/presentation/providers/mission_lifecycle_controller.dart';
import 'package:forge/features/missions/presentation/providers/mission_lifecycle_state.dart';

import '../../../../support/fake_dashboard_overrides.dart';

TransmissionScript _buildScript({
  int lineCount = 3,
  Duration lineDuration = const Duration(milliseconds: 5),
}) {
  return TransmissionScript(
    id: 'test-script',
    characterId: CharacterId.watcher,
    date: DateTime.utc(2026, 8, 5),
    introLabel: 'Incoming Transmission',
    dialogueLines: [
      for (var i = 0; i < lineCount; i++)
        DialogueLine(
          id: 'line-$i',
          text: 'Line number $i.',
          estimatedDuration: lineDuration,
          pauseAfter: Duration.zero,
        ),
    ],
    missionTitle: 'Test Mission',
    missionDescription: 'A test mission.',
    category: 'Fitness',
    difficulty: MissionDifficulty.easy,
    estimatedMinutes: 5,
    xpReward: 10,
    requiresProof: false,
    completionConditions: const ['Do the thing'],
    accessibilitySummary: 'A test transmission.',
  );
}

class _ScriptedRepository implements TransmissionRepository {
  _ScriptedRepository(this._resolve);

  final TransmissionScript Function() _resolve;

  @override
  Future<TransmissionScript> getDailyTransmission(
    DashboardOverview dashboard,
  ) async {
    return _resolve();
  }
}

Future<void> _pumpUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      fail('Timed out waiting for condition after ${stopwatch.elapsed}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  (ProviderContainer, ProviderSubscription<DailyTransmissionState>)
  buildContainer({
    TransmissionScript? script,
    TransmissionRepository? repository,
    FakeTtsService? tts,
    CharacterAnimationController? engine,
  }) {
    final resolvedRepository =
        repository ?? _ScriptedRepository(() => script ?? _buildScript());
    final resolvedTts = tts ?? FakeTtsService();
    final resolvedEngine = engine ?? FakeCharacterAnimationController();

    final container = ProviderContainer(
      overrides: [
        ...dashboardPopulatedOverrides(),
        transmissionRepositoryProvider.overrideWithValue(resolvedRepository),
        ttsServiceProvider.overrideWithValue(resolvedTts as TtsService),
        characterAnimationControllerFactoryProvider.overrideWithValue(
          () => resolvedEngine,
        ),
      ],
    );
    // Keeps the autoDispose provider alive for the container's lifetime,
    // matching "the transmission screen is on screen" — tests that want to
    // exercise disposal close this subscription explicitly.
    final sub = container.listen(
      dailyTransmissionControllerProvider,
      (_, _) {},
    );
    return (container, sub);
  }

  test('a normal run progresses through every phase in order', () async {
    final script = _buildScript();
    final (container, _) = buildContainer(script: script);
    addTearDown(container.dispose);

    final phases = <TransmissionPhase>[];
    container.listen(dailyTransmissionControllerProvider, (prev, next) {
      if (phases.isEmpty || phases.last != next.phase) phases.add(next.phase);
    }, fireImmediately: true);

    await _pumpUntil(
      () =>
          container.read(dailyTransmissionControllerProvider).phase ==
          TransmissionPhase.awaitingAcceptance,
    );

    expect(phases, [
      TransmissionPhase.preparing,
      TransmissionPhase.incoming,
      TransmissionPhase.entering,
      TransmissionPhase.speaking,
      TransmissionPhase.missionReveal,
      TransmissionPhase.awaitingAcceptance,
    ]);
  });

  test('each line is spoken exactly once during a normal run', () async {
    final tts = FakeTtsService();
    final script = _buildScript();
    final (container, _) = buildContainer(script: script, tts: tts);
    addTearDown(container.dispose);

    await _pumpUntil(
      () =>
          container.read(dailyTransmissionControllerProvider).phase ==
          TransmissionPhase.awaitingAcceptance,
    );

    expect(tts.spokenTexts, script.dialogueLines.map((l) => l.text).toList());
  });

  test('skip during speech jumps straight to mission reveal', () async {
    final tts = FakeTtsService(autoComplete: false);
    final script = _buildScript();
    final (container, _) = buildContainer(script: script, tts: tts);
    addTearDown(container.dispose);

    await _pumpUntil(() => tts.spokenTexts.length == 1);
    expect(
      container.read(dailyTransmissionControllerProvider).phase,
      TransmissionPhase.speaking,
    );

    container.read(dailyTransmissionControllerProvider.notifier).skip();

    await _pumpUntil(
      () =>
          container.read(dailyTransmissionControllerProvider).phase ==
          TransmissionPhase.awaitingAcceptance,
    );

    final state = container.read(dailyTransmissionControllerProvider);
    expect(state.dialogueIndex, script.dialogueLines.length - 1);
    // Only the first line was actually dispatched before the skip cut in.
    expect(tts.spokenTexts.length, 1);
  });

  test(
    'skip during the incoming/entering intro jumps straight to reveal',
    () async {
      // With every fake resolving near-instantly, polling for "still in
      // incoming/entering" would be racy — a listener that fires `skip()`
      // the instant that phase is *reached* (Riverpod notifies listeners
      // synchronously on each `state =` assignment) catches it precisely,
      // regardless of how fast the rest of the run proceeds.
      final script = _buildScript();
      final (container, _) = buildContainer(script: script);
      addTearDown(container.dispose);

      var skippedDuringIntro = false;
      container.listen(dailyTransmissionControllerProvider, (prev, next) {
        if (!skippedDuringIntro &&
            (next.phase == TransmissionPhase.incoming ||
                next.phase == TransmissionPhase.entering)) {
          skippedDuringIntro = true;
          container.read(dailyTransmissionControllerProvider.notifier).skip();
        }
      }, fireImmediately: true);

      await _pumpUntil(
        () =>
            container.read(dailyTransmissionControllerProvider).phase ==
            TransmissionPhase.awaitingAcceptance,
      );

      expect(skippedDuringIntro, isTrue);
      expect(
        container.read(dailyTransmissionControllerProvider).dialogueIndex,
        script.dialogueLines.length - 1,
      );
    },
  );

  test('skip() is rejected once the mission is already revealed', () async {
    final script = _buildScript();
    final (container, _) = buildContainer(script: script);
    addTearDown(container.dispose);

    await _pumpUntil(
      () =>
          container.read(dailyTransmissionControllerProvider).phase ==
          TransmissionPhase.awaitingAcceptance,
    );
    final before = container.read(dailyTransmissionControllerProvider);

    container.read(dailyTransmissionControllerProvider.notifier).skip();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final after = container.read(dailyTransmissionControllerProvider);
    expect(after.phase, before.phase);
    expect(after.dialogueIndex, before.dialogueIndex);
  });

  test('muting mid-speech stops audio immediately and pacing falls back to '
      'estimated duration for the rest of the run', () async {
    final tts = FakeTtsService(autoComplete: false);
    final script = _buildScript(lineDuration: const Duration(milliseconds: 15));
    final (container, _) = buildContainer(script: script, tts: tts);
    addTearDown(container.dispose);

    await _pumpUntil(() => tts.spokenTexts.length == 1);

    await container
        .read(dailyTransmissionControllerProvider.notifier)
        .toggleMute();

    expect(container.read(dailyTransmissionControllerProvider).muted, isTrue);
    expect(tts.stopCalls, greaterThanOrEqualTo(1));

    await _pumpUntil(
      () =>
          container.read(dailyTransmissionControllerProvider).phase ==
          TransmissionPhase.awaitingAcceptance,
    );
    // No further speak() calls happened once muted.
    expect(tts.spokenTexts.length, 1);
  });

  test('replay after reveal restarts dialogue from the first line', () async {
    final tts = FakeTtsService();
    final script = _buildScript();
    final (container, _) = buildContainer(script: script, tts: tts);
    addTearDown(container.dispose);
    final notifier = container.read(
      dailyTransmissionControllerProvider.notifier,
    );

    await _pumpUntil(
      () =>
          container.read(dailyTransmissionControllerProvider).phase ==
          TransmissionPhase.awaitingAcceptance,
    );
    expect(tts.spokenTexts.length, script.dialogueLines.length);

    await notifier.replay();

    expect(
      container.read(dailyTransmissionControllerProvider).phase,
      TransmissionPhase.awaitingAcceptance,
    );
    expect(tts.spokenTexts.length, script.dialogueLines.length * 2);
  });

  test('rapid replay taps do not cause overlapping runs or crash', () async {
    final tts = FakeTtsService();
    final script = _buildScript();
    final (container, _) = buildContainer(script: script, tts: tts);
    addTearDown(container.dispose);
    final notifier = container.read(
      dailyTransmissionControllerProvider.notifier,
    );

    await _pumpUntil(
      () =>
          container.read(dailyTransmissionControllerProvider).phase ==
          TransmissionPhase.awaitingAcceptance,
    );

    await Future.wait([
      notifier.replay(),
      notifier.replay(),
      notifier.replay(),
    ]);

    final state = container.read(dailyTransmissionControllerProvider);
    expect(state.phase, TransmissionPhase.awaitingAcceptance);
    expect(state.dialogueIndex, script.dialogueLines.length - 1);
  });

  test(
    'TTS unavailable still advances subtitles via estimated duration',
    () async {
      final tts = FakeTtsService(simulateUnavailable: true);
      final script = _buildScript(
        lineDuration: const Duration(milliseconds: 10),
      );
      final (container, _) = buildContainer(script: script, tts: tts);
      addTearDown(container.dispose);

      await _pumpUntil(
        () =>
            container.read(dailyTransmissionControllerProvider).phase ==
            TransmissionPhase.awaitingAcceptance,
      );

      expect(
        container.read(dailyTransmissionControllerProvider).ttsAvailable,
        isFalse,
      );
      expect(tts.spokenTexts, isEmpty);
    },
  );

  test(
    'repository failure surfaces an error phase; retry can recover',
    () async {
      var shouldFail = true;
      final (container, _) = buildContainer(
        repository: _ScriptedRepository(() {
          if (shouldFail) throw const TransmissionException('boom');
          return _buildScript();
        }),
      );
      addTearDown(container.dispose);

      await _pumpUntil(
        () =>
            container.read(dailyTransmissionControllerProvider).phase ==
            TransmissionPhase.error,
      );
      expect(
        container.read(dailyTransmissionControllerProvider).offlineFallback,
        isFalse,
      );

      shouldFail = false;
      await container
          .read(dailyTransmissionControllerProvider.notifier)
          .retry();

      expect(
        container.read(dailyTransmissionControllerProvider).phase,
        TransmissionPhase.awaitingAcceptance,
      );
    },
  );

  test('offline exception sets the offline-fallback flag', () async {
    final (container, _) = buildContainer(
      repository: _ScriptedRepository(
        () => throw const TransmissionOfflineException(),
      ),
    );
    addTearDown(container.dispose);

    await _pumpUntil(
      () =>
          container.read(dailyTransmissionControllerProvider).phase ==
          TransmissionPhase.error,
    );
    expect(
      container.read(dailyTransmissionControllerProvider).offlineFallback,
      isTrue,
    );
  });

  test(
    'acceptMission() is rejected before the mission has been revealed',
    () async {
      final (container, _) = buildContainer();
      addTearDown(container.dispose);

      await container
          .read(dailyTransmissionControllerProvider.notifier)
          .acceptMission();

      expect(
        container.read(dailyTransmissionControllerProvider).missionAccepted,
        isFalse,
      );
    },
  );

  test('accepting the mission sets missionAccepted and appends a real '
      'MissionAccepted event to the mission event log', () async {
    final script = _buildScript();
    final (container, _) = buildContainer(script: script);
    addTearDown(container.dispose);
    final notifier = container.read(
      dailyTransmissionControllerProvider.notifier,
    );

    await _pumpUntil(
      () =>
          container.read(dailyTransmissionControllerProvider).phase ==
          TransmissionPhase.awaitingAcceptance,
    );
    await notifier.acceptMission();

    final state = container.read(dailyTransmissionControllerProvider);
    expect(state.phase, TransmissionPhase.accepted);
    expect(state.missionAccepted, isTrue);

    final instance = container.read(missionInstanceProvider)!;
    final lifecycleState = container.read(
      missionLifecycleControllerProvider(instance.instanceId),
    );
    expect(lifecycleState, isA<MissionLifecycleReady>());
    expect(
      (lifecycleState as MissionLifecycleReady).aggregate.lifecycleState,
      lifecycle.MissionLifecycleState.accepted,
    );
  });

  test(
    'setReducedMotion propagates to every character-engine play() call',
    () async {
      final engine = FakeCharacterAnimationController();
      final script = _buildScript();
      final (container, _) = buildContainer(script: script, engine: engine);
      addTearDown(container.dispose);

      container
          .read(dailyTransmissionControllerProvider.notifier)
          .setReducedMotion(true);

      await _pumpUntil(
        () =>
            container.read(dailyTransmissionControllerProvider).phase ==
            TransmissionPhase.awaitingAcceptance,
      );

      expect(engine.reducedMotionFlags, isNotEmpty);
      expect(engine.reducedMotionFlags.every((flag) => flag), isTrue);
    },
  );

  test(
    'disposing the container stops tts and disposes the character engine',
    () async {
      final tts = FakeTtsService(autoComplete: false);
      final engine = FakeCharacterAnimationController();
      final script = _buildScript();
      final (container, _) = buildContainer(
        script: script,
        tts: tts,
        engine: engine,
      );

      await _pumpUntil(() => tts.spokenTexts.isNotEmpty);
      container.dispose();

      expect(tts.stopCalls, greaterThanOrEqualTo(1));
      expect(engine.disposed, isTrue);
    },
  );

  test('leaving the route (closing the last listener) stops tts and disposes '
      'the character engine', () async {
    final tts = FakeTtsService(autoComplete: false);
    final engine = FakeCharacterAnimationController();
    final script = _buildScript();
    final (container, sub) = buildContainer(
      script: script,
      tts: tts,
      engine: engine,
    );
    addTearDown(container.dispose);

    await _pumpUntil(() => tts.spokenTexts.isNotEmpty);
    sub.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(tts.stopCalls, greaterThanOrEqualTo(1));
    expect(engine.disposed, isTrue);
  });
}
