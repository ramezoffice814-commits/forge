import '../entities/achievement_progress.dart';
import 'get_progression_usecase.dart';

class GetUnlockedAchievementsUseCase {
  const GetUnlockedAchievementsUseCase(this._getProgression);

  final GetProgressionUseCase _getProgression;

  Future<List<AchievementProgress>> call(String userId) async {
    final aggregate = await _getProgression(userId);
    return [
      ...aggregate.achievements.alreadyUnlocked,
      ...aggregate.achievements.newlyUnlocked,
    ];
  }
}
