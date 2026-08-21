import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../../../core/backend/backend_mode.dart';
import '../../../../core/backend/backend_providers.dart';
import '../../../progression/presentation/providers/progression_providers.dart';
import '../../data/mock/mock_leaderboard_repository.dart';
import '../../data/repositories/in_memory_competition_repository.dart';
import '../../data/supabase/supabase_leaderboard_repository.dart';
import '../../domain/repositories/competition_repository.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../../domain/services/cached_leaderboard_fetch.dart';
import '../../domain/usecases/build_league_group_usecase.dart';
import '../../domain/usecases/calculate_competitive_mission_score_usecase.dart';
import '../../domain/usecases/calculate_season_score_usecase.dart';
import '../../domain/usecases/calculate_weekly_score_usecase.dart';
import '../../domain/usecases/evaluate_league_movement_usecase.dart';
import '../../domain/usecases/get_current_competition_state_usecase.dart';
import '../../domain/usecases/get_hall_of_fame_usecase.dart';
import '../../domain/usecases/get_season_progress_usecase.dart';
import '../../domain/usecases/rank_league_group_usecase.dart';

/// One competition store for the whole app session — a plain
/// (non-autoDispose) provider, same reasoning as
/// `progressionRepositoryProvider`.
final competitionRepositoryProvider = Provider<CompetitionRepository>((ref) {
  return InMemoryCompetitionRepository();
});

/// Reuses the same local identity progression already resolves, so a
/// competitive completion accumulates onto the same user the mock
/// population and mission engine already run against.
final currentCompetitionUserIdProvider = Provider<String>((ref) {
  return ref.watch(currentProgressionUserIdProvider);
});

/// The one seam between `CompetitionController` and wall-clock time.
/// Unlike mission/progression XP (which is always anchored to a specific
/// completion's own timestamp), "which week/season is current" is
/// inherently a function of real time — but tests and goldens still need a
/// fixed, overridable clock rather than the real `DateTime.now()`, so
/// rendered week numbers and rookie-window math never silently drift as
/// real time passes.
final competitionClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final calculateCompetitiveMissionScoreUseCaseProvider = Provider((ref) {
  return CalculateCompetitiveMissionScoreUseCase(
    ref.watch(competitionRepositoryProvider),
  );
});

final calculateWeeklyScoreUseCaseProvider = Provider((ref) {
  return CalculateWeeklyScoreUseCase(ref.watch(competitionRepositoryProvider));
});

final calculateSeasonScoreUseCaseProvider = Provider((ref) {
  return CalculateSeasonScoreUseCase(ref.watch(competitionRepositoryProvider));
});

final buildLeagueGroupUseCaseProvider = Provider((ref) {
  return const BuildLeagueGroupUseCase();
});

final rankLeagueGroupUseCaseProvider = Provider((ref) {
  return const RankLeagueGroupUseCase();
});

final evaluateLeagueMovementUseCaseProvider = Provider((ref) {
  return const EvaluateLeagueMovementUseCase();
});

final getCurrentCompetitionStateUseCaseProvider = Provider((ref) {
  return GetCurrentCompetitionStateUseCase(
    ref.watch(competitionRepositoryProvider),
  );
});

final getHallOfFameUseCaseProvider = Provider((ref) {
  return GetHallOfFameUseCase(ref.watch(competitionRepositoryProvider));
});

final getSeasonProgressUseCaseProvider = Provider((ref) {
  return GetSeasonProgressUseCase(ref.watch(competitionRepositoryProvider));
});

/// [MockLeaderboardRepository] in mock mode, the real
/// [SupabaseLeaderboardRepository] in live mode — mirrors
/// `rawBackendClientProvider`'s mode switch exactly (spec section 8:
/// "preserve mock mode").
final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  final mode = ref.watch(backendModeProvider);
  return switch (mode) {
    BackendMode.mock => const MockLeaderboardRepository(),
    BackendMode.liveSupabase => SupabaseLeaderboardRepository(
      supa.Supabase.instance.client,
    ),
  };
});

final cachedLeaderboardFetcherProvider = Provider<CachedLeaderboardFetcher>((
  ref,
) {
  return CachedLeaderboardFetcher(ref.watch(leaderboardRepositoryProvider));
});
