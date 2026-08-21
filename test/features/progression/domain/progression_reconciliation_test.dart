import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/progression/data/catalog/level_catalog.dart';
import 'package:forge/features/progression/domain/entities/user_progression_profile.dart';
import 'package:forge/features/progression/domain/entities/user_title.dart';
import 'package:forge/features/progression/domain/services/progression_reconciliation.dart';

void main() {
  final catalog = LevelCatalog.build();
  final now = DateTime.utc(2026, 8, 19);
  const title = UserTitle(
    id: 'starter',
    name: 'Starter',
    description: 'd',
    unlockReason: 'r',
  );

  UserProgressionProfile profile({
    required int confirmedXp,
    required int provisionalXp,
    Set<String> unlocked = const {},
  }) {
    return UserProgressionProfile(
      userId: 'user-1',
      currentLevel: 1,
      totalConfirmedXp: confirmedXp,
      provisionalXp: provisionalXp,
      currentTitle: title,
      unlockedAchievementIds: unlocked,
      categoryProgress: const {},
      createdAt: now,
      updatedAt: now,
    );
  }

  group('applyConfirmedReward', () {
    test('subtracts the confirmed delta out of the provisional bucket', () {
      final result = ProgressionReconciliation.applyConfirmedReward(
        current: profile(confirmedXp: 0, provisionalXp: 20),
        confirmedXpDelta: 12,
        confirmedTotalXp: 12,
        catalog: catalog,
        now: now,
      );
      expect(result.totalConfirmedXp, 12);
      expect(result.provisionalXp, 8);
    });

    test('never lets remaining provisional XP go negative', () {
      final result = ProgressionReconciliation.applyConfirmedReward(
        current: profile(confirmedXp: 0, provisionalXp: 5),
        confirmedXpDelta: 12,
        confirmedTotalXp: 12,
        catalog: catalog,
        now: now,
      );
      expect(result.provisionalXp, 0);
    });

    test(
      'confirmed total always comes from the server value, never computed locally',
      () {
        final result = ProgressionReconciliation.applyConfirmedReward(
          current: profile(confirmedXp: 100, provisionalXp: 5),
          confirmedXpDelta: 5,
          confirmedTotalXp: 200, // authoritative — not 100 + 5.
          catalog: catalog,
          now: now,
        );
        expect(result.totalConfirmedXp, 200);
      },
    );

    test(
      'currentLevel stays preview-inclusive (confirmed + remaining provisional)',
      () {
        final result = ProgressionReconciliation.applyConfirmedReward(
          current: profile(confirmedXp: 0, provisionalXp: 0),
          confirmedXpDelta: 0,
          confirmedTotalXp: 1000, // level 6+ worth of XP.
          catalog: catalog,
          now: now,
        );
        expect(result.currentLevel, greaterThan(1));
      },
    );
  });

  group('mergeConfirmedAchievements', () {
    test('only reports genuinely new ids for celebration', () {
      final result = ProgressionReconciliation.mergeConfirmedAchievements(
        current: profile(
          confirmedXp: 0,
          provisionalXp: 0,
          unlocked: {'already-had'},
        ),
        confirmedAchievementIds: ['already-had', 'brand-new'],
      );
      expect(result.newlyUnlockedAchievementIds, ['brand-new']);
      expect(result.profile.unlockedAchievementIds, {
        'already-had',
        'brand-new',
      });
    });

    test(
      'a fully-redundant confirmation changes nothing and reports nothing new',
      () {
        final current = profile(
          confirmedXp: 0,
          provisionalXp: 0,
          unlocked: {'a', 'b'},
        );
        final result = ProgressionReconciliation.mergeConfirmedAchievements(
          current: current,
          confirmedAchievementIds: ['a', 'b'],
        );
        expect(result.newlyUnlockedAchievementIds, isEmpty);
        expect(identical(result.profile, current), isTrue);
      },
    );
  });
}
