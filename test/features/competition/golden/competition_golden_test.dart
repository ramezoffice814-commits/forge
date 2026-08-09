// Image-comparison golden tests — platform-dependent rendering (see
// dart_test.yaml and docs/ARCHITECTURE.md's golden-test notes). Excluded
// from the standard `flutter test --exclude-tags=golden` run and executed
// on their own via `flutter test --tags=golden`.
//
// Every case here renders a widget directly from a hand-built, fixed
// domain object rather than through the full controller/repository chain
// — deterministic by construction, and immune to drift if the mock
// catalog's scoring formula ever changes.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/competition/domain/entities/hall_of_fame_record.dart';
import 'package:forge/features/competition/domain/entities/leaderboard_entry.dart';
import 'package:forge/features/competition/domain/entities/league_movement.dart';
import 'package:forge/features/competition/domain/entities/rookie_status.dart';
import 'package:forge/features/competition/domain/entities/season_definition.dart';
import 'package:forge/features/competition/domain/entities/season_score.dart';
import 'package:forge/features/competition/domain/enums/hall_of_fame_record_type.dart';
import 'package:forge/features/competition/domain/enums/promotion_status.dart';
import 'package:forge/features/competition/domain/enums/season_status.dart';
import 'package:forge/features/competition/domain/enums/competition_week_status.dart';
import 'package:forge/features/competition/domain/entities/competition_week.dart';
import 'package:forge/features/competition/domain/services/competition_ranking_result.dart';
import 'package:forge/features/competition/domain/usecases/get_season_progress_usecase.dart';
import 'package:forge/features/competition/presentation/widgets/hall_of_fame_list.dart';
import 'package:forge/features/competition/presentation/widgets/league_leaderboard_list.dart';
import 'package:forge/features/competition/presentation/widgets/league_movement_preview_card.dart';
import 'package:forge/features/competition/presentation/widgets/rookie_placement_banner.dart';
import 'package:forge/features/competition/presentation/widgets/season_progress_card.dart';
import 'package:google_fonts/google_fonts.dart';

CompetitionRankingResult _fixedRanking() {
  const entries = [
    LeaderboardEntry(
      userId: 'u1',
      displayName: 'Aiko',
      league: 'Iron',
      rank: 1,
      weeklyScore: 210,
      activeDays: 6,
      promotionStatus: PromotionStatus.promotionZone,
    ),
    LeaderboardEntry(
      userId: 'u2',
      displayName: 'Bram',
      league: 'Iron',
      rank: 2,
      weeklyScore: 190,
      activeDays: 5,
      promotionStatus: PromotionStatus.promotionZone,
    ),
    LeaderboardEntry(
      userId: 'test-user',
      displayName: 'You',
      league: 'Iron',
      rank: 3,
      weeklyScore: 140,
      activeDays: 4,
      promotionStatus: PromotionStatus.safeZone,
    ),
    LeaderboardEntry(
      userId: 'u4',
      displayName: 'Coral',
      league: 'Iron',
      rank: 4,
      weeklyScore: 90,
      activeDays: 3,
      promotionStatus: PromotionStatus.demotionZone,
    ),
    LeaderboardEntry(
      userId: 'u5',
      displayName: 'Dax',
      league: 'Iron',
      rank: 5,
      weeklyScore: 40,
      activeDays: 2,
      promotionStatus: PromotionStatus.demotionZone,
    ),
  ];
  return const CompetitionRankingResult(
    entries: entries,
    promotionZoneUserIds: {'u1', 'u2'},
    demotionZoneUserIds: {'u4', 'u5'},
    tieBreakNotes: {},
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ForgeTheme.dark(),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void main() {
  setUpAll(() {
    // Golden tests must not depend on a network font fetch.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpAtSize(WidgetTester tester, Size size, Widget child) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(child));
    await tester.pumpAndSettle();
  }

  testWidgets('league leaderboard — mobile reference size', (tester) async {
    await pumpAtSize(
      tester,
      const Size(412, 500),
      LeagueLeaderboardList(
        ranking: _fixedRanking(),
        currentUserId: 'test-user',
      ),
    );
    await expectLater(
      find.byType(LeagueLeaderboardList),
      matchesGoldenFile('goldens/league_leaderboard_mobile.png'),
    );
  });

  testWidgets('league leaderboard — wide/tablet reference size', (
    tester,
  ) async {
    await pumpAtSize(
      tester,
      const Size(1024, 400),
      LeagueLeaderboardList(
        ranking: _fixedRanking(),
        currentUserId: 'test-user',
      ),
    );
    await expectLater(
      find.byType(LeagueLeaderboardList),
      matchesGoldenFile('goldens/league_leaderboard_wide.png'),
    );
  });

  testWidgets('rookie placement banner', (tester) async {
    await pumpAtSize(
      tester,
      const Size(412, 220),
      RookiePlacementBanner(
        status: RookieStatus(
          isRookie: true,
          daysSinceFirstCompetitiveCompletion: 2,
          competitiveCompletionCount: 3,
          protectionEndsAt: DateTime.utc(2026, 8, 20),
          reason: 'Placement period — matched with newer participants',
        ),
      ),
    );
    await expectLater(
      find.byType(RookiePlacementBanner),
      matchesGoldenFile('goldens/rookie_placement_banner.png'),
    );
  });

  testWidgets('league movement preview — promotion zone', (tester) async {
    await pumpAtSize(
      tester,
      const Size(412, 220),
      const LeagueMovementPreviewCard(
        preview: LeagueMovementPreview(
          promotionThresholdRank: 5,
          demotionThresholdRank: 20,
          currentRank: 3,
          zone: PromotionStatus.promotionZone,
          pointsToNextRank: 12,
        ),
      ),
    );
    await expectLater(
      find.byType(LeagueMovementPreviewCard),
      matchesGoldenFile('goldens/league_movement_promotion_zone.png'),
    );
  });

  testWidgets('season progress card', (tester) async {
    final season = SeasonDefinition(
      id: 'season-1',
      name: 'Season 1: Ember Rising',
      startsAt: DateTime.utc(2026, 8, 3),
      endsAt: DateTime.utc(2026, 9, 28),
      status: SeasonStatus.active,
      weekCount: 8,
      scoringVersion: 1,
      leagueRulesVersion: 1,
      promotionRulesVersion: 1,
      active: true,
    );
    final week = CompetitionWeek(
      seasonId: 'season-1',
      weekNumber: 3,
      startsAt: DateTime.utc(2026, 8, 17),
      endsAt: DateTime.utc(2026, 8, 24),
      status: CompetitionWeekStatus.active,
    );
    final seasonScore = SeasonScore(
      userId: 'test-user',
      seasonId: 'season-1',
      countedWeeks: const [1, 2],
      droppedWeeks: const [],
      totalSeasonScore: 310,
      scoringRule: 'Best 6 of 8 weeks played',
    );

    await pumpAtSize(
      tester,
      const Size(412, 260),
      SeasonProgressCard(
        snapshot: SeasonProgressSnapshot(
          season: season,
          currentWeek: week,
          seasonScore: seasonScore,
          weekProgressFraction: 3 / 8,
        ),
      ),
    );
    await expectLater(
      find.byType(SeasonProgressCard),
      matchesGoldenFile('goldens/season_progress_card.png'),
    );
  });

  testWidgets('Hall of Fame list', (tester) async {
    final records = [
      HallOfFameRecord(
        id: 'hof-1',
        userId: 'u1',
        displayName: 'Bram',
        seasonId: 'season-0',
        type: HallOfFameRecordType.bestSeasonFinish,
        description: 'Finished Season 0 as #1 in Mythic League',
        achievedAt: DateTime.utc(2026, 7, 1),
      ),
      HallOfFameRecord(
        id: 'hof-2',
        userId: 'u2',
        displayName: 'Coral',
        seasonId: 'season-0',
        type: HallOfFameRecordType.bestWeeklyFinish,
        description: 'Best single-week score of Season 0',
        achievedAt: DateTime.utc(2026, 7, 1),
      ),
    ];

    await pumpAtSize(
      tester,
      const Size(412, 320),
      HallOfFameList(records: records),
    );
    await expectLater(
      find.byType(HallOfFameList),
      matchesGoldenFile('goldens/hall_of_fame_list.png'),
    );
  });
}
