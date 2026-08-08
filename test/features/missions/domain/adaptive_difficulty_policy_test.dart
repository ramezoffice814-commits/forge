import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/entities/behavioral_history.dart';
import 'package:forge/features/missions/domain/entities/user_discipline_profile.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/missions/domain/enums/mission_difficulty_level.dart';
import 'package:forge/features/missions/domain/policies/adaptive_difficulty_policy.dart';

const _profile = UserDisciplineProfile(userId: 'u1');
const _category = MissionCategory.fitness;

BehavioralHistory _historyWith(
  CategoryPerformance performance, {
  int recentDifficultyChangeCount = 0,
}) {
  return BehavioralHistory(
    categoryPerformance: {_category: performance},
    recentDifficultyChangeCount: recentDifficultyChangeCount,
  );
}

void main() {
  test('a single isolated success does not increase difficulty', () {
    final history = _historyWith(
      const CategoryPerformance(
        category: _category,
        completed: 1,
        lastDifficulty: MissionDifficultyLevel.easy,
        consecutiveComparableSuccesses: 1,
      ),
    );
    final resolution = AdaptiveDifficultyPolicy.resolve(
      category: _category,
      profile: _profile,
      history: history,
      recoveryActive: false,
    );
    expect(resolution.resolvedDifficulty, MissionDifficultyLevel.easy);
  });

  test(
    'three stable comparable successes increase difficulty by one level',
    () {
      final history = _historyWith(
        const CategoryPerformance(
          category: _category,
          completed: 3,
          averageEffort: 2.5,
          lastDifficulty: MissionDifficultyLevel.easy,
          consecutiveComparableSuccesses: 3,
        ),
      );
      final resolution = AdaptiveDifficultyPolicy.resolve(
        category: _category,
        profile: _profile,
        history: history,
        recoveryActive: false,
      );
      expect(resolution.resolvedDifficulty, MissionDifficultyLevel.moderate);
      expect(resolution.reasonCodes, contains('stableSuccessIncrease'));
    },
  );

  test(
    'difficulty never jumps more than one level even with a long streak',
    () {
      final history = _historyWith(
        const CategoryPerformance(
          category: _category,
          completed: 10,
          averageEffort: 2.0,
          lastDifficulty: MissionDifficultyLevel.easy,
          consecutiveComparableSuccesses: 10,
        ),
      );
      final resolution = AdaptiveDifficultyPolicy.resolve(
        category: _category,
        profile: _profile,
        history: history,
        recoveryActive: false,
      );
      expect(resolution.resolvedDifficulty, MissionDifficultyLevel.moderate);
    },
  );

  test('two comparable misses decrease difficulty by one level', () {
    final history = _historyWith(
      const CategoryPerformance(
        category: _category,
        missed: 2,
        lastDifficulty: MissionDifficultyLevel.moderate,
        consecutiveComparableMisses: 2,
      ),
    );
    final resolution = AdaptiveDifficultyPolicy.resolve(
      category: _category,
      profile: _profile,
      history: history,
      recoveryActive: false,
    );
    expect(resolution.resolvedDifficulty, MissionDifficultyLevel.easy);
    expect(resolution.reasonCodes, contains('repeatedMissesDecrease'));
  });

  test('excessive self-reported effort decreases difficulty even without '
      'misses', () {
    final history = _historyWith(
      const CategoryPerformance(
        category: _category,
        completed: 3,
        averageEffort: 4.8,
        lastDifficulty: MissionDifficultyLevel.moderate,
      ),
    );
    final resolution = AdaptiveDifficultyPolicy.resolve(
      category: _category,
      profile: _profile,
      history: history,
      recoveryActive: false,
    );
    expect(resolution.resolvedDifficulty, MissionDifficultyLevel.easy);
    expect(resolution.reasonCodes, contains('highEffortDecrease'));
  });

  test(
    'manual intensity cap is always respected regardless of performance',
    () {
      final profile = _profile.copyWith(
        manualIntensityCap: MissionDifficultyLevel.easy,
      );
      final history = _historyWith(
        const CategoryPerformance(
          category: _category,
          completed: 10,
          averageEffort: 2.0,
          lastDifficulty: MissionDifficultyLevel.moderate,
          consecutiveComparableSuccesses: 5,
        ),
      );
      final resolution = AdaptiveDifficultyPolicy.resolve(
        category: _category,
        profile: profile,
        history: history,
        recoveryActive: false,
      );
      expect(resolution.resolvedDifficulty, MissionDifficultyLevel.easy);
      expect(resolution.reasonCodes, contains('manualCap'));
    },
  );

  test('recovery caps difficulty at easy regardless of performance', () {
    final history = _historyWith(
      const CategoryPerformance(
        category: _category,
        completed: 10,
        lastDifficulty: MissionDifficultyLevel.challenging,
        consecutiveComparableSuccesses: 5,
      ),
    );
    final resolution = AdaptiveDifficultyPolicy.resolve(
      category: _category,
      profile: _profile,
      history: history,
      recoveryActive: true,
    );
    expect(resolution.resolvedDifficulty, MissionDifficultyLevel.easy);
    expect(resolution.reasonCodes, contains('recoveryCap'));
  });

  test('a recent adjustment triggers a stabilization hold, avoiding '
      'oscillation', () {
    final history = _historyWith(
      const CategoryPerformance(
        category: _category,
        completed: 5,
        averageEffort: 2.0,
        lastDifficulty: MissionDifficultyLevel.easy,
        consecutiveComparableSuccesses: 5,
      ),
      recentDifficultyChangeCount: 2,
    );
    final resolution = AdaptiveDifficultyPolicy.resolve(
      category: _category,
      profile: _profile,
      history: history,
      recoveryActive: false,
    );
    // Would otherwise increase given 5 stable successes — held instead.
    expect(resolution.resolvedDifficulty, MissionDifficultyLevel.easy);
    expect(resolution.reasonCodes, contains('stabilizing'));
  });

  test('a category with no history at all defaults to easy with low '
      'confidence', () {
    final resolution = AdaptiveDifficultyPolicy.resolve(
      category: _category,
      profile: _profile,
      history: const BehavioralHistory(),
      recoveryActive: false,
    );
    expect(resolution.resolvedDifficulty, MissionDifficultyLevel.easy);
    expect(resolution.confidence, lessThan(0.5));
  });
}
