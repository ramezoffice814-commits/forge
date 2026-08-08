import '../aggregates/progression_aggregate.dart';
import '../repositories/progression_repository.dart';

/// The read path the UI actually wants: the full derived aggregate (level
/// definition, next-level progress, achievement evaluation, snapshot) —
/// not just the bare profile `ProgressionRepository.getProgressionProfile`
/// returns.
class GetProgressionUseCase {
  const GetProgressionUseCase(this._repository);

  final ProgressionRepository _repository;

  Future<ProgressionAggregate> call(String userId, {DateTime? now}) async {
    final titles = _repository.getTitleDefinitions();
    // The lowest-priority title is the intended baseline/fallback — see
    // `TitleCatalog.starter`, which is always priority 0.
    final fallback = [...titles]
      ..sort((a, b) => a.priority.compareTo(b.priority));

    return ProgressionAggregate.rehydrate(
      userId: userId,
      events: _repository.eventsForUser(userId),
      completions: _repository.completionsForUser(userId),
      levelCatalog: _repository.getLevels(),
      titleCatalog: titles,
      titleFallback: fallback.first,
      achievementCatalog: _repository.getAchievementDefinitions(),
      now: now ?? DateTime.now(),
    );
  }
}
