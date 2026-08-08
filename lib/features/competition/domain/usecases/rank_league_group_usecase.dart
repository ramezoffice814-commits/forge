import '../entities/league_definition.dart';
import '../services/competition_ranking_engine.dart';
import '../services/competition_ranking_result.dart';

/// Thin wrapper over `CompetitionRankingEngine` — kept as its own use case
/// (rather than folding into `GetCurrentCompetitionStateUseCase`) so a
/// group can be re-ranked on its own, e.g. by a future admin/debug view or
/// a test that only cares about ranking, not the full state assembly.
class RankLeagueGroupUseCase {
  const RankLeagueGroupUseCase();

  CompetitionRankingResult call({
    required List<CompetitionRankingParticipant> participants,
    required LeagueDefinition league,
    required List<LeagueDefinition> allLeagues,
    Set<String> protectedUserIds = const {},
  }) {
    return CompetitionRankingEngine.rank(
      participants: participants,
      league: league,
      allLeagues: allLeagues,
      protectedUserIds: protectedUserIds,
    );
  }
}
