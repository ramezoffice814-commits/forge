import '../entities/league_definition.dart';
import '../entities/league_group.dart';
import '../policies/mock_league_grouping_policy.dart';

/// Thin, intentionally dumb wrapper — the actual deterministic bucketing
/// logic lives in `MockLeagueGroupingPolicy` so it can be unit tested
/// without a repository in the loop.
class BuildLeagueGroupUseCase {
  const BuildLeagueGroupUseCase();

  List<LeagueGroup> call({
    required String seasonId,
    required int weekNumber,
    required LeagueDefinition league,
    required List<CompetitionGroupingContext> participants,
    required DateTime createdAt,
  }) {
    return MockLeagueGroupingPolicy.buildGroups(
      seasonId: seasonId,
      weekNumber: weekNumber,
      league: league,
      participants: participants,
      createdAt: createdAt,
    );
  }
}
