import '../../../missions/domain/enums/mission_category.dart';
import '../../domain/aggregates/progression_aggregate.dart';
import '../../domain/entities/achievement_definition.dart';
import '../../domain/entities/category_progress.dart';
import '../../domain/entities/completed_mission_summary.dart';
import '../../domain/entities/level_definition.dart';
import '../../domain/entities/user_progression_profile.dart';
import '../../domain/entities/user_title.dart';
import '../../domain/events/progression_event.dart';
import '../../domain/repositories/progression_repository.dart';
import '../catalog/achievement_catalog.dart';
import '../catalog/level_catalog.dart';
import '../catalog/title_catalog.dart';

/// The only implementation this phase ships — no database, exactly like
/// `InMemoryMissionEventRepository`. [getProgressionProfile] always
/// re-derives from [completionsForUser]/[eventsForUser] via
/// `ProgressionAggregate.rehydrate`; [saveLocalPreview] is a cache hook a
/// future sync layer could read instead, kept here for interface
/// completeness but not load-bearing for correctness.
///
/// [now] defaults to real wall-clock time — real mission completions are
/// timestamped for real (see `SystemMissionClock`), so this module's own
/// "today" needs to track the same clock rather than a fixed mock date, or
/// a live completion's timestamp could end up "after" this module's idea
/// of now. `MockProgressionContext.seed` anchors its synthetic history to
/// whatever "now" actually is at seed time for the same reason. Tests that
/// need reproducible output inject a fixed callback here instead.
class InMemoryProgressionRepository implements ProgressionRepository {
  InMemoryProgressionRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  final Map<String, List<CompletedMissionSummary>> _completionsByUser = {};
  final Map<String, List<ProgressionEvent>> _eventsByUser = {};
  final Map<String, UserProgressionProfile> _cachedProfiles = {};

  final List<LevelDefinition> _levels = LevelCatalog.build();
  final List<AchievementDefinition> _achievements = AchievementCatalog.build();
  final List<UserTitleDefinition> _titles = TitleCatalog.build();

  @override
  List<LevelDefinition> getLevels() => List.unmodifiable(_levels);

  @override
  List<AchievementDefinition> getAchievementDefinitions() =>
      List.unmodifiable(_achievements);

  @override
  List<UserTitleDefinition> getTitleDefinitions() => List.unmodifiable(_titles);

  @override
  List<CompletedMissionSummary> completionsForUser(String userId) =>
      List.unmodifiable(_completionsByUser[userId] ?? const []);

  @override
  Future<void> recordCompletion(CompletedMissionSummary summary) async {
    _completionsByUser.putIfAbsent(summary.userId, () => []).add(summary);
  }

  @override
  List<ProgressionEvent> eventsForUser(String userId) =>
      List.unmodifiable(_eventsByUser[userId] ?? const []);

  @override
  Future<ProgressionEvent> appendEvent(ProgressionEvent draft) async {
    final existing = _eventsByUser.putIfAbsent(draft.userId, () => []);
    final assigned = draft.withSequenceNumber(existing.length + 1);
    existing.add(assigned);
    return assigned;
  }

  ProgressionAggregate _rehydrate(String userId) {
    return ProgressionAggregate.rehydrate(
      userId: userId,
      events: eventsForUser(userId),
      completions: completionsForUser(userId),
      levelCatalog: _levels,
      titleCatalog: _titles,
      titleFallback: TitleCatalog.starter,
      achievementCatalog: _achievements,
      now: _now(),
    );
  }

  @override
  Future<UserProgressionProfile> getProgressionProfile(String userId) async {
    return _rehydrate(userId).profile;
  }

  @override
  Future<Map<MissionCategory, CategoryProgress>> getCategoryProgress(
    String userId,
  ) async {
    return _rehydrate(userId).profile.categoryProgress;
  }

  @override
  Future<void> saveLocalPreview(UserProgressionProfile profile) async {
    _cachedProfiles[profile.userId] = profile;
  }

  @override
  void clearForUser(String userId) {
    _completionsByUser.remove(userId);
    _eventsByUser.remove(userId);
    _cachedProfiles.remove(userId);
  }
}
