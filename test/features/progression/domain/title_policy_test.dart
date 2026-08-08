import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/missions/domain/enums/mission_category.dart';
import 'package:forge/features/progression/data/catalog/title_catalog.dart';
import 'package:forge/features/progression/domain/entities/mission_history_snapshot.dart';
import 'package:forge/features/progression/domain/policies/title_policy.dart';

void main() {
  final catalog = TitleCatalog.build();

  MissionHistorySnapshot snapshot({
    int totalCompletions = 0,
    int categoriesTried = 0,
    int currentStreakDays = 0,
    int advancedOrChallenging = 0,
  }) {
    return MissionHistorySnapshot(
      totalCompletions: totalCompletions,
      completionsByCategory: const {},
      completionsByDefinitionId: const {},
      categoriesTried: MissionCategory.values.take(categoriesTried).toSet(),
      currentStreakDays: currentStreakDays,
      longestStreakDays: currentStreakDays,
      daysSinceLastCompletion: 0,
      advancedOrChallengingCompletions: advancedOrChallenging,
      recoveryCompletions: 0,
      justReturnedFromInactivity: false,
    );
  }

  test('a brand-new user gets the fallback starter title', () {
    final title = TitlePolicy.evaluate(
      snapshot: snapshot(),
      catalog: catalog,
      fallback: TitleCatalog.starter,
      reasonFor: (d) => d.description,
    );
    expect(title.id, TitleCatalog.starter.id);
  });

  test('a higher-priority match wins when multiple criteria are met', () {
    // Meets both "the_builder" (priority 10) and "the_architect"
    // (priority 30) simultaneously.
    final title = TitlePolicy.evaluate(
      snapshot: snapshot(totalCompletions: 20, advancedOrChallenging: 15),
      catalog: catalog,
      fallback: TitleCatalog.starter,
      reasonFor: (d) => d.description,
    );
    expect(title.id, 'the_architect');
  });

  test('evaluation is deterministic for identical input', () {
    final s = snapshot(currentStreakDays: 7);
    final a = TitlePolicy.evaluate(
      snapshot: s,
      catalog: catalog,
      fallback: TitleCatalog.starter,
      reasonFor: (d) => d.description,
    );
    final b = TitlePolicy.evaluate(
      snapshot: s,
      catalog: catalog,
      fallback: TitleCatalog.starter,
      reasonFor: (d) => d.description,
    );
    expect(a.id, b.id);
  });

  test('the resolved title always carries a non-empty unlock reason', () {
    final title = TitlePolicy.evaluate(
      snapshot: snapshot(currentStreakDays: 7),
      catalog: catalog,
      fallback: TitleCatalog.starter,
      reasonFor: (d) => d.description,
    );
    expect(title.unlockReason, isNotEmpty);
  });
}
