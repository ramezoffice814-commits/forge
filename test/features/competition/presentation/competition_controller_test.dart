import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/competition/presentation/providers/competition_controller.dart';
import 'package:forge/features/competition/presentation/providers/competition_providers.dart';
import 'package:forge/features/competition/presentation/providers/competition_state.dart';
import 'package:forge/features/progression/domain/entities/xp_reward_evaluation.dart';

import '../../../support/fake_auth_overrides.dart';
import '../../../support/mission_lifecycle_test_helpers.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 8, 10, 9);

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
        competitionClockProvider.overrideWithValue(() => fixedNow),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  XpRewardEvaluation evaluationFor(String missionInstanceId, int xp) {
    return XpRewardEvaluation(
      missionInstanceId: missionInstanceId,
      baseXp: xp,
      difficultyMultiplier: 1,
      categoryMultiplier: 1,
      consistencyBonus: 0,
      recoveryBonus: 0,
      penaltyAdjustments: 0,
      finalXpPreview: xp,
      reasons: const [],
      evaluationVersion: 'test',
    );
  }

  test(
    'build() resolves into CompetitionReady for an authenticated user',
    () async {
      final container = buildContainer();
      await container.read(competitionControllerProvider.notifier).ready;
      final state = container.read(competitionControllerProvider);
      expect(state, isA<CompetitionReady>());
    },
  );

  test('a brand-new user is reported as a rookie', () async {
    final container = buildContainer();
    await container.read(competitionControllerProvider.notifier).ready;
    final state =
        container.read(competitionControllerProvider) as CompetitionReady;
    expect(state.current.rookieStatus.isRookie, isTrue);
  });

  test('reactToMissionCompletion is idempotent per mission instance', () async {
    final container = buildContainer();
    final notifier = container.read(competitionControllerProvider.notifier);
    await notifier.ready;

    final userId = container.read(currentCompetitionUserIdProvider);
    final instance = testMissionInstance(instanceId: 'once-only');

    await notifier.reactToMissionCompletion(
      instance: instance,
      xpEvaluation: evaluationFor(instance.instanceId, 20),
      userId: userId,
    );
    final afterFirst =
        (container.read(competitionControllerProvider) as CompetitionReady)
            .current
            .weeklyScore
            .cappedScore;

    await notifier.reactToMissionCompletion(
      instance: instance,
      xpEvaluation: evaluationFor(instance.instanceId, 20),
      userId: userId,
    );
    final afterSecond =
        (container.read(competitionControllerProvider) as CompetitionReady)
            .current
            .weeklyScore
            .cappedScore;

    expect(afterSecond, afterFirst);
  });

  test(
    'a second, different mission completion increases the weekly score',
    () async {
      final container = buildContainer();
      final notifier = container.read(competitionControllerProvider.notifier);
      await notifier.ready;
      final userId = container.read(currentCompetitionUserIdProvider);

      await notifier.reactToMissionCompletion(
        instance: testMissionInstance(instanceId: 'm1'),
        xpEvaluation: evaluationFor('m1', 20),
        userId: userId,
      );
      final afterFirst =
          (container.read(competitionControllerProvider) as CompetitionReady)
              .current
              .weeklyScore
              .cappedScore;

      await notifier.reactToMissionCompletion(
        instance: testMissionInstance(instanceId: 'm2'),
        xpEvaluation: evaluationFor('m2', 20),
        userId: userId,
      );
      final afterSecond =
          (container.read(competitionControllerProvider) as CompetitionReady)
              .current
              .weeklyScore
              .cappedScore;

      expect(afterSecond, greaterThan(afterFirst));
    },
  );
}
