import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/progression/data/catalog/achievement_catalog.dart';

/// The server's canonical achievement `stable_key` set — mirrors
/// `supabase/migrations/20260820090100_achievement_canonical_ids.sql`
/// exactly. There is no live database to query in this environment (see
/// the Phase 11 final report), so this constant is the mechanical check
/// this test performs: it must be kept in sync with that migration by
/// hand whenever either catalog changes — which is exactly what this
/// test is for, since a drift between the two is a silent bug (an
/// achievement whose id never matches anything, on either side).
const _serverCanonicalAchievementIds = <String>{
  'first_mission',
  'momentum_3_day',
  'consistency_7_day',
  'tried_3_categories',
  'tried_all_categories',
  'coding_10',
  'reading_10',
  'fitness_10',
  'returned_from_break',
  'recovery_5',
  'advanced_10',
  'mastery_50_total',
};

void main() {
  test(
    'every server-canonical achievement id matches exactly one Flutter AchievementDefinition',
    () {
      final flutterIds = AchievementCatalog.build().map((a) => a.id).toSet();

      final serverOnly = _serverCanonicalAchievementIds.difference(flutterIds);
      expect(
        serverOnly,
        isEmpty,
        reason:
            'These server-canonical ids have no matching Flutter '
            'AchievementDefinition: $serverOnly',
      );
    },
  );

  test(
    'every Flutter AchievementDefinition id matches exactly one server-canonical achievement',
    () {
      final flutterIds = AchievementCatalog.build().map((a) => a.id).toSet();

      final flutterOnly = flutterIds.difference(_serverCanonicalAchievementIds);
      expect(
        flutterOnly,
        isEmpty,
        reason:
            'These Flutter AchievementDefinition ids have no matching '
            'server-canonical achievement: $flutterOnly',
      );
    },
  );

  test('no id appears twice in the Flutter catalog', () {
    final ids = AchievementCatalog.build().map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test(
    'the Flutter catalog has exactly as many entries as the canonical set',
    () {
      expect(
        AchievementCatalog.build().length,
        _serverCanonicalAchievementIds.length,
      );
    },
  );
}
