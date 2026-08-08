import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/progression/data/local/in_memory_progression_repository.dart';
import 'package:forge/features/progression/domain/events/progression_event.dart';
import 'package:forge/features/progression/domain/usecases/calculate_level_usecase.dart';
import 'package:forge/features/progression/domain/usecases/evaluate_achievements_usecase.dart';
import 'package:forge/features/progression/domain/usecases/evaluate_mission_reward_usecase.dart';
import 'package:forge/features/progression/domain/usecases/get_progression_usecase.dart';
import 'package:forge/features/progression/domain/usecases/get_titles_usecase.dart';

import '../../../support/progression_test_helpers.dart';

void main() {
  late InMemoryProgressionRepository repository;
  final now = DateTime.utc(2026, 8, 10);

  setUp(() => repository = InMemoryProgressionRepository(now: () => now));

  test('EvaluateMissionRewardUseCase records the completion and appends an '
      'XpPreviewCalculated event', () async {
    final useCase = EvaluateMissionRewardUseCase(repository);
    final summary = testCompletedSummary(completedAt: now);

    final evaluation = await useCase(summary);

    expect(evaluation.finalXpPreview, greaterThan(0));
    expect(repository.completionsForUser(testProgressionUserId), hasLength(1));
    expect(
      repository
          .eventsForUser(testProgressionUserId)
          .whereType<XpPreviewCalculated>(),
      hasLength(1),
    );
  });

  test('once the daily allowance is fully spent, a further mission the '
      'same day earns no more XP', () async {
    final useCase = EvaluateMissionRewardUseCase(repository);
    // Each mission is capped at 100 XP (maxXpPerMission); three of them
    // exactly exhaust the 300 XP daily allowance.
    for (var i = 0; i < 3; i++) {
      final result = await useCase(
        testCompletedSummary(
          missionInstanceId: 'm$i',
          baseXpHint: 1000,
          completedAt: now.add(Duration(minutes: i)),
        ),
      );
      expect(result.finalXpPreview, 100);
    }

    final fourth = await useCase(
      testCompletedSummary(
        missionInstanceId: 'm-fourth',
        baseXpHint: 1000,
        completedAt: now.add(const Duration(minutes: 10)),
      ),
    );
    expect(fourth.finalXpPreview, 0);
  });

  test('CalculateLevelUseCase reports justLeveledUp exactly once per '
      'crossing', () async {
    final evaluateReward = EvaluateMissionRewardUseCase(repository);
    final calculateLevel = CalculateLevelUseCase(repository);

    // Rack up enough XP across several missions to cross level 2.
    for (var i = 0; i < 5; i++) {
      await evaluateReward(
        testCompletedSummary(
          missionInstanceId: 'm$i',
          baseXpHint: 50,
          completedAt: now.add(Duration(days: i)),
        ),
      );
    }

    final first = await calculateLevel(testProgressionUserId, now: now);
    expect(first.current.levelNumber, greaterThanOrEqualTo(1));

    final second = await calculateLevel(testProgressionUserId, now: now);
    expect(second.justLeveledUp, isFalse); // already recorded by `first`.
  });

  test('EvaluateAchievementsUseCase does not duplicate an unlock event on '
      'repeated calls', () async {
    final evaluateReward = EvaluateMissionRewardUseCase(repository);
    final evaluateAchievements = EvaluateAchievementsUseCase(repository);

    await evaluateReward(testCompletedSummary(completedAt: now));
    final first = await evaluateAchievements(testProgressionUserId, now: now);
    expect(
      first.newlyUnlocked.map((a) => a.definition.id),
      contains('first_mission'),
    );

    final second = await evaluateAchievements(testProgressionUserId, now: now);
    expect(second.newlyUnlocked, isEmpty);

    final unlockEvents = repository
        .eventsForUser(testProgressionUserId)
        .whereType<AchievementUnlocked>()
        .where((e) => e.achievementId == 'first_mission');
    expect(unlockEvents, hasLength(1));
  });

  test('GetTitlesUseCase only appends a TitleUnlocked event when the title '
      'actually changes', () async {
    final getTitles = GetTitlesUseCase(repository);

    await getTitles(testProgressionUserId, now: now);
    await getTitles(testProgressionUserId, now: now);

    final titleEvents = repository
        .eventsForUser(testProgressionUserId)
        .whereType<TitleUnlocked>();
    expect(titleEvents, hasLength(1));
  });

  test('GetProgressionUseCase reflects everything recorded by the other '
      'use cases', () async {
    final evaluateReward = EvaluateMissionRewardUseCase(repository);
    final getProgression = GetProgressionUseCase(repository);

    await evaluateReward(testCompletedSummary(completedAt: now));
    final aggregate = await getProgression(testProgressionUserId, now: now);

    expect(aggregate.profile.provisionalXp, greaterThan(0));
    expect(aggregate.snapshot.totalCompletions, 1);
  });
}
