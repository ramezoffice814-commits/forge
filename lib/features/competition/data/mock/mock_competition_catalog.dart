import '../../../missions/domain/enums/mission_category.dart';
import '../../domain/entities/hall_of_fame_record.dart';
import '../../domain/entities/league_definition.dart';
import '../../domain/entities/season_definition.dart';
import '../../domain/entities/weekly_competition_score.dart';
import '../../domain/enums/hall_of_fame_record_type.dart';
import '../../domain/enums/integrity_signal.dart';
import '../../domain/enums/season_status.dart';
import '../../domain/policies/competition_scoring_constants.dart';
import '../../domain/services/competition_ranking_engine.dart';
import 'league_catalog.dart';

/// A deterministic 42-user mock population (7 per league × 6 leagues) plus
/// a fixed current season and Hall of Fame — no `Random()`, no runtime
/// variance. Every value is derived purely from a participant's index and
/// the requested week number, so `participantsForLeague` called twice with
/// the same arguments always returns byte-identical results (spec section
/// 24's "no random runtime values").
abstract final class MockCompetitionCatalog {
  static const int _participantsPerLeague = 7;

  static const List<String> _namePool = [
    'Aiko',
    'Bram',
    'Coral',
    'Dax',
    'Esi',
    'Finn',
    'Greta',
    'Hiro',
    'Ines',
    'Jael',
    'Kofi',
    'Lior',
    'Maya',
    'Noor',
    'Omar',
    'Petra',
    'Quinn',
    'Rosa',
    'Sami',
    'Tove',
    'Uma',
    'Vik',
    'Wren',
    'Xu',
    'Yara',
    'Zane',
    'Ada',
    'Bo',
    'Ciro',
    'Dev',
    'Elin',
    'Faye',
    'Gus',
    'Hana',
    'Ivo',
    'Jun',
    'Kira',
    'Leo',
    'Mira',
    'Nils',
    'Opal',
    'Pia',
  ];

  static final DateTime seasonReferenceStart = DateTime.utc(2026, 8, 3);

  static SeasonDefinition currentSeason() {
    return SeasonDefinition(
      id: 'season-1',
      name: 'Season 1: Ember Rising',
      startsAt: seasonReferenceStart,
      endsAt: seasonReferenceStart.add(
        Duration(days: 7 * CompetitionScoringConstants.defaultSeasonWeekCount),
      ),
      status: SeasonStatus.active,
      weekCount: CompetitionScoringConstants.defaultSeasonWeekCount,
      scoringVersion: CompetitionScoringConstants.scoringVersion,
      leagueRulesVersion: CompetitionScoringConstants.leagueRulesVersion,
      promotionRulesVersion: CompetitionScoringConstants.promotionRulesVersion,
      active: true,
    );
  }

  static List<LeagueDefinition> leagues() => LeagueCatalog.leagues;

  /// Index 0 within each league is always the seeded rookie (see
  /// [protectedUserIds]); index 6 is always the seeded integrity-warning
  /// case — fixed positions so tests can reference them directly rather
  /// than searching for them.
  static bool _isSeededWarningCase(int indexInLeague) => indexInLeague == 6;

  static List<CompetitionRankingParticipant> participantsForLeague({
    required String leagueId,
    required int weekNumber,
  }) {
    final league = LeagueCatalog.leagues.firstWhere((l) => l.id == leagueId);
    final baseScore = 40.0 + league.tier.index * 60.0;

    return List.generate(_participantsPerLeague, (i) {
      final userId = 'mock-${league.id}-$i';
      final name =
          _namePool[(league.tier.index * _participantsPerLeague + i) %
              _namePool.length];

      // Two fixed participants (index 4 in Ember, week 1 only) share an
      // identical score so ranking tests have a deterministic tie to
      // exercise the documented tie-break order.
      final tieOverride =
          leagueId == 'league-ember' && weekNumber == 1 && (i == 3 || i == 4);

      final variation = tieOverride
          ? 12.0
          : ((i * 37 + weekNumber * 13) % 90) - 20.0;
      final rawScore = (baseScore + variation).clamp(0.0, double.infinity);
      final cappedScore = rawScore.clamp(
        0.0,
        CompetitionScoringConstants.maxScorePerWeek,
      );

      final activeDays = (3 + (i + weekNumber) % 5).clamp(0, 7);
      final completedMissionCount = activeDays + (i % 3);

      final categories = MissionCategory.values;
      final categoriesUsed = <MissionCategory>{
        categories[i % categories.length],
        categories[(i + weekNumber) % categories.length],
      };

      final integrityFlags = _isSeededWarningCase(i)
          ? const {IntegritySignal.excessiveVolume}
          : const <IntegritySignal>{};

      final weeklyScore = WeeklyCompetitionScore(
        userId: userId,
        seasonId: 'season-1',
        weekNumber: weekNumber,
        rawScore: rawScore,
        cappedScore: cappedScore,
        completedMissionCount: completedMissionCount,
        activeDays: activeDays,
        categoriesUsed: categoriesUsed,
        integrityFlags: integrityFlags,
        scoreBreakdown: {
          'missions': cappedScore * 0.9,
          'consistencyBonus': cappedScore * 0.1,
        },
      );

      return CompetitionRankingParticipant(
        userId: userId,
        displayName: name,
        weeklyScore: weeklyScore,
        averageDifficulty: 1.0 + (i % 5) * 0.3,
        scoreAttainedAt: seasonReferenceStart.add(
          Duration(days: 7 * (weekNumber - 1) + 6, hours: 20 - i),
        ),
      );
    });
  }

  static Set<String> protectedUserIds(String leagueId, int weekNumber) {
    // The seeded rookie (index 0) is always protected; nobody else is, in
    // this fixed mock population.
    return {'mock-$leagueId-0'};
  }

  static bool isMockParticipantRookie(String userId) {
    return userId.endsWith('-0');
  }

  static List<HallOfFameRecord> hallOfFame() {
    final achievedAt = seasonReferenceStart.subtract(const Duration(days: 30));
    return [
      HallOfFameRecord(
        id: 'hof-1',
        userId: 'mock-league-mythic-1',
        displayName: 'Bram',
        seasonId: 'season-0',
        type: HallOfFameRecordType.bestSeasonFinish,
        description: 'Finished Season 0 as #1 in Mythic League',
        achievedAt: achievedAt,
      ),
      HallOfFameRecord(
        id: 'hof-2',
        userId: 'mock-league-obsidian-2',
        displayName: 'Coral',
        seasonId: 'season-0',
        type: HallOfFameRecordType.bestWeeklyFinish,
        description: 'Best single-week score of Season 0',
        achievedAt: achievedAt,
      ),
      HallOfFameRecord(
        id: 'hof-3',
        userId: 'mock-league-mythic-3',
        displayName: 'Dax',
        seasonId: 'season-0',
        type: HallOfFameRecordType.highestLeagueReached,
        description: 'Reached Mythic League',
        achievedAt: achievedAt,
      ),
      HallOfFameRecord(
        id: 'hof-4',
        userId: 'mock-league-titanium-1',
        displayName: 'Esi',
        seasonId: 'season-0',
        type: HallOfFameRecordType.mostConsistentSeason,
        description: 'Active every single day of Season 0',
        achievedAt: achievedAt,
      ),
    ];
  }
}
