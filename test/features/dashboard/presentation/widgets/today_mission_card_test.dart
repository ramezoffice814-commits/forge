import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/dashboard/domain/entities/mission_preview.dart';
import 'package:forge/features/dashboard/presentation/widgets/today_mission_card.dart';
import 'package:forge/features/missions/domain/aggregates/mission_aggregate.dart';
import 'package:forge/features/missions/domain/aggregates/mission_lifecycle_state.dart'
    as lifecycle;
import 'package:forge/features/missions/domain/aggregates/mission_reward_state.dart';
import 'package:forge/features/missions/domain/entities/mission_instance.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/missions/domain/enums/proof_policy.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_definition.dart';
import 'package:forge/features/missions/domain/progress/mission_progress_state.dart';
import 'package:forge/features/missions/presentation/providers/mission_lifecycle_controller.dart';
import 'package:forge/features/missions/presentation/providers/mission_lifecycle_state.dart';
import 'package:forge/shared/widgets/forge_button.dart';
import 'package:go_router/go_router.dart';

/// Overrides a single `missionLifecycleControllerProvider` family member
/// with a fixed state, bypassing the real mission-instance/repository
/// plumbing entirely — these widget tests only care about how
/// `TodayMissionCard` *renders* a given lifecycle state.
class _FixedLifecycleController extends MissionLifecycleController {
  _FixedLifecycleController(this._fixed);

  final MissionLifecycleControllerState _fixed;

  @override
  MissionLifecycleControllerState build(String missionInstanceId) => _fixed;
}

MissionAggregate _aggregateWith(
  String instanceId,
  lifecycle.MissionLifecycleState lifecycleState,
) {
  final instance = MissionInstance(
    instanceId: instanceId,
    definitionId: 'def',
    assignedDate: DateTime.utc(2026, 8, 10),
    title: 'Test Mission',
    description: 'Subtitle',
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

void main() {
  Widget wrap(MissionPreview mission, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: ForgeTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TodayMissionCard(mission: mission),
          ),
        ),
      ),
    );
  }

  MissionPreview missionWith(
    MissionStatus status, {
    bool requiresProof = false,
    bool transmissionAvailable = true,
  }) {
    return MissionPreview(
      id: 'm',
      title: 'Test Mission',
      subtitle: 'Subtitle',
      category: 'Fitness',
      difficulty: MissionDifficulty.easy,
      estimatedMinutes: 5,
      xpReward: 10,
      status: status,
      transmissionAvailable: transmissionAvailable,
      requiresProof: requiresProof,
    );
  }

  final expectations = {
    MissionStatus.notStarted: ('View Mission', true),
    MissionStatus.viewed: ('Accept Mission', true),
    MissionStatus.accepted: ('Continue Mission', true),
    MissionStatus.readyToSubmit: ('Submit Completion', true),
    MissionStatus.completed: ('Completed', false),
    MissionStatus.unavailableOffline: ('Unavailable Offline', false),
  };

  for (final entry in expectations.entries) {
    final (label, enabled) = entry.value;
    testWidgets('$entry renders "$label" ${enabled ? 'enabled' : 'disabled'}', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(missionWith(entry.key)));

      final button = tester.widget<ForgeButton>(
        find.widgetWithText(ForgeButton, label),
      );
      expect(button.onPressed == null, !enabled);
    });
  }

  testWidgets('shows a proof-required tag only when the mission requires it', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(missionWith(MissionStatus.notStarted, requiresProof: true)),
    );
    expect(find.text('Proof required'), findsOneWidget);
  });

  testWidgets('omits the proof-required tag when proof is not needed', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(missionWith(MissionStatus.notStarted, requiresProof: false)),
    );
    expect(find.text('Proof required'), findsNothing);
  });

  testWidgets('replay and mute controls are present but disabled', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(missionWith(MissionStatus.notStarted)));

    final replay = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.replay_rounded),
    );
    final mute = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.volume_off_rounded),
    );
    expect(replay.onPressed, isNull);
    expect(mute.onPressed, isNull);
  });

  testWidgets('a viewed mission (not eligible to open the transmission) opens '
      'ActiveMissionPage instead', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: TodayMissionCard(
                mission: missionWith(MissionStatus.viewed),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/home/mission/:missionInstanceId',
          name: 'active-mission',
          builder: (context, state) =>
              const Scaffold(body: Text('active-mission-page-marker')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: ForgeTheme.dark(),
          routerConfig: router,
        ),
      ),
    );

    final button = find.widgetWithText(ForgeButton, 'Accept Mission');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('active-mission-page-marker'), findsOneWidget);
  });

  testWidgets(
    'a not-started mission with transmission available opens the Daily '
    'Transmission route instead of showing the placeholder',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: TodayMissionCard(
                  mission: missionWith(MissionStatus.notStarted),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/home/transmission',
            name: 'daily-transmission',
            builder: (context, state) =>
                const Scaffold(body: Text('transmission-page-marker')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: ForgeTheme.dark(),
            routerConfig: router,
          ),
        ),
      );

      final button = find.widgetWithText(ForgeButton, 'View Mission');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('transmission-page-marker'), findsOneWidget);
    },
  );

  testWidgets('reflects mission acceptance from the event-derived aggregate', (
    tester,
  ) async {
    final mission = missionWith(MissionStatus.notStarted);
    final aggregate = _aggregateWith(
      mission.id,
      lifecycle.MissionLifecycleState.accepted,
    );
    final container = ProviderContainer(
      overrides: [
        missionLifecycleControllerProvider.overrideWith(
          () => _FixedLifecycleController(MissionLifecycleReady(aggregate)),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ForgeTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: TodayMissionCard(mission: mission),
            ),
          ),
        ),
      ),
    );

    expect(
      find.widgetWithText(ForgeButton, 'Continue Mission'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ForgeButton, 'View Mission'), findsNothing);
  });
}
