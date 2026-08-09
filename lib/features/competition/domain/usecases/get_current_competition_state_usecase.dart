import 'package:flutter/foundation.dart';

import '../entities/competition_week.dart';
import '../entities/league_definition.dart';
import '../entities/league_movement.dart';
import '../entities/rookie_status.dart';
import '../entities/season_definition.dart';
import '../entities/weekly_competition_score.dart';
import '../policies/competition_calendar.dart';
import '../policies/rookie_placement_policy.dart';
import '../repositories/competition_repository.dart';
import '../services/competition_ranking_engine.dart';
import '../services/competition_ranking_result.dart';
import 'calculate_weekly_score_usecase.dart';
import 'evaluate_league_movement_usecase.dart';

/// The single ready-to-render snapshot `CompetitionController` needs —
/// assembled here rather than scattered across several controller calls,
/// but deliberately not an oversized "CompetitionService": every piece
/// this pulls together already exists as its own testable policy/use case.
@immutable
class CurrentCompetitionState {
  const CurrentCompetitionState({
    required this.season,
    required this.week,
    required this.league,
    required this.allLeagues,
    required this.weeklyScore,
    required this.rookieStatus,
    required this.ranking,
    required this.movementPreview,
  });

  final SeasonDefinition season;
  final CompetitionWeek week;
  final LeagueDefinition league;
  final List<LeagueDefinition> allLeagues;
  final WeeklyCompetitionScore weeklyScore;
  final RookieStatus rookieStatus;
  final CompetitionRankingResult ranking;
  final LeagueMovementPreview movementPreview;
}

class GetCurrentCompetitionStateUseCase {
  const GetCurrentCompetitionStateUseCase(this._repository);

  final CompetitionRepository _repository;

  Future<CurrentCompetitionState> call(
    String userId, {
    required DateTime now,
    required String displayName,
    String? avatarUrl,
  }) async {
    final season = await _repository.getCurrentSeason();
    final weeks = CompetitionCalendar.weeksFor(season, now);
    final week = CompetitionCalendar.currentWeekFor(season, now) ?? weeks.last;
    final leagues = await _repository.getLeagueDefinitions();

    final completions = await _repository.completionsForUser(userId);
    final sortedCompletions = [...completions]
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    final firstCompletionAt = sortedCompletions.isEmpty
        ? now
        : sortedCompletions.first.completedAt;

    final rookieStatus = RookiePlacementPolicy.statusFor(
      firstCompetitiveCompletionAt: firstCompletionAt,
      competitiveCompletionCount: completions.length,
      now: now,
    );

    final leagueId = await _repository.getCurrentLeagueIdForUser(userId);
    final league = leagues.firstWhere(
      (l) => l.id == leagueId,
      orElse: () => leagues.first,
    );

    final weeklyScore = await CalculateWeeklyScoreUseCase(_repository)(
      userId: userId,
      week: week,
    );

    final weekCompletions = completions
        .where((c) => week.contains(c.completedAt))
        .toList();
    final averageDifficulty = weekCompletions.isEmpty
        ? 0.0
        : weekCompletions.fold<int>(0, (sum, c) => sum + c.difficulty.index) /
              weekCompletions.length;

    final mockParticipants = await _repository.participantsForLeague(
      leagueId: league.id,
      weekNumber: week.weekNumber,
    );
    final selfParticipant = CompetitionRankingParticipant(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      weeklyScore: weeklyScore,
      averageDifficulty: averageDifficulty,
      scoreAttainedAt: sortedCompletions.isEmpty
          ? now
          : sortedCompletions.last.completedAt,
    );

    final participants = [
      ...mockParticipants.where((p) => p.userId != userId),
      selfParticipant,
    ];

    final protectedIds = await _repository.protectedUserIdsForLeague(
      league.id,
      week.weekNumber,
    );
    final effectiveProtected = rookieStatus.isRookie
        ? {...protectedIds, userId}
        : protectedIds;

    final ranking = CompetitionRankingEngine.rank(
      participants: participants,
      league: league,
      allLeagues: leagues,
      protectedUserIds: effectiveProtected,
    );

    final movementPreview = const EvaluateLeagueMovementUseCase().previewFor(
      userId: userId,
      ranking: ranking,
      promotionCount: league.promotionCount,
      demotionCount: league.demotionCount,
    );

    return CurrentCompetitionState(
      season: season,
      week: week,
      league: league,
      allLeagues: leagues,
      weeklyScore: weeklyScore,
      rookieStatus: rookieStatus,
      ranking: ranking,
      movementPreview: movementPreview,
    );
  }
}
