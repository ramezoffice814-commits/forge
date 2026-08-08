import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../missions/presentation/providers/mission_providers.dart';
import '../../data/local/in_memory_progression_repository.dart';
import '../../domain/repositories/progression_repository.dart';
import '../../domain/usecases/calculate_level_usecase.dart';
import '../../domain/usecases/evaluate_achievements_usecase.dart';
import '../../domain/usecases/evaluate_mission_reward_usecase.dart';
import '../../domain/usecases/get_category_progress_usecase.dart';
import '../../domain/usecases/get_progression_usecase.dart';
import '../../domain/usecases/get_titles_usecase.dart';
import '../../domain/usecases/get_unlocked_achievements_usecase.dart';

/// One progression store for the whole app session — a plain
/// (non-autoDispose) provider, same reasoning as
/// `missionEventRepositoryProvider`: it must survive navigating away from
/// and back to any progression-reading screen.
final progressionRepositoryProvider = Provider<ProgressionRepository>((ref) {
  return InMemoryProgressionRepository();
});

/// Reuses the same local identity the mission engine already runs
/// against, so a live mission completion accumulates onto the same
/// progression profile the mock history was seeded for — see
/// `MockProgressionContext`.
final currentProgressionUserIdProvider = Provider<String>((ref) {
  return ref.watch(currentMissionUserIdProvider);
});

final evaluateMissionRewardUseCaseProvider = Provider((ref) {
  return EvaluateMissionRewardUseCase(ref.watch(progressionRepositoryProvider));
});

final getProgressionUseCaseProvider = Provider((ref) {
  return GetProgressionUseCase(ref.watch(progressionRepositoryProvider));
});

final calculateLevelUseCaseProvider = Provider((ref) {
  return CalculateLevelUseCase(ref.watch(progressionRepositoryProvider));
});

final evaluateAchievementsUseCaseProvider = Provider((ref) {
  return EvaluateAchievementsUseCase(ref.watch(progressionRepositoryProvider));
});

final getTitlesUseCaseProvider = Provider((ref) {
  return GetTitlesUseCase(ref.watch(progressionRepositoryProvider));
});

final getUnlockedAchievementsUseCaseProvider = Provider((ref) {
  return GetUnlockedAchievementsUseCase(
    ref.watch(getProgressionUseCaseProvider),
  );
});

final getCategoryProgressUseCaseProvider = Provider((ref) {
  return GetCategoryProgressUseCase(ref.watch(progressionRepositoryProvider));
});
