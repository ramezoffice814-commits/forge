import '../../../missions/domain/enums/mission_category.dart';
import '../entities/achievement_definition.dart';
import '../entities/category_progress.dart';
import '../entities/completed_mission_summary.dart';
import '../entities/level_definition.dart';
import '../entities/user_progression_profile.dart';
import '../entities/user_title.dart';
import '../events/progression_event.dart';

/// Local-only storage for progression facts — completions, the progression
/// event audit trail, and the catalogs everything is evaluated against.
/// Never itself authoritative (see the module's trust-boundary notes); a
/// future backend is the only thing that can confirm real XP.
abstract class ProgressionRepository {
  /// The fully-derived current profile — see `ProgressionAggregate
  /// .rehydrate`, which every implementation should delegate to.
  Future<UserProgressionProfile> getProgressionProfile(String userId);

  Future<Map<MissionCategory, CategoryProgress>> getCategoryProgress(
    String userId,
  );

  List<LevelDefinition> getLevels();
  List<AchievementDefinition> getAchievementDefinitions();
  List<UserTitleDefinition> getTitleDefinitions();

  /// Persists a snapshot the caller wants remembered as "the current
  /// profile" — a hook for a future sync layer; reads never depend on this
  /// having been called, since [getProgressionProfile] always re-derives
  /// from [completionsForUser]/[eventsForUser].
  Future<void> saveLocalPreview(UserProgressionProfile profile);

  List<CompletedMissionSummary> completionsForUser(String userId);
  Future<void> recordCompletion(CompletedMissionSummary summary);

  List<ProgressionEvent> eventsForUser(String userId);
  Future<ProgressionEvent> appendEvent(ProgressionEvent draft);

  /// Wipes all local progression state for [userId] — e.g. on sign-out, so
  /// nothing provisional survives into the next session's device state.
  void clearForUser(String userId);
}
