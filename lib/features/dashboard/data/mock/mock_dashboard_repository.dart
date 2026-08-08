import '../../domain/dashboard_failure.dart';
import '../../domain/dashboard_repository.dart';
import '../../domain/entities/dashboard_overview.dart';
import '../../domain/entities/league_preview.dart';
import '../../domain/entities/mission_preview.dart';
import '../../domain/entities/weekly_snapshot.dart';

/// Deterministic canned scenarios — no randomness, so widget/golden tests
/// stay stable. Each scenario always returns exactly the same data.
enum DashboardMockScenario {
  normalActive,
  newUser,
  recoveryMode,
  completedMission,
  offlineCached,
  offlineNoCache,
  empty,
  networkError,
  repositoryError,
}

class MockDashboardRepository implements DashboardRepository {
  const MockDashboardRepository({
    required this.scenario,
    this.displayName = 'Alex Rivera',
    this.missionOverride,
  });

  final DashboardMockScenario scenario;
  final String displayName;

  /// When provided (the mission-selection engine has resolved today's
  /// mission), this replaces the scenario's own hardcoded mission preview —
  /// see `dashboard_repository_provider.dart` for the wiring. `null` keeps
  /// every existing scenario's mission text exactly as before, which is
  /// what happens on Dashboard's very first, pre-mission-selection render.
  final MissionPreview? missionOverride;

  static const _simulatedDelay = Duration(milliseconds: 300);
  static final _referenceTime = DateTime.utc(2026, 8, 5, 7, 30);

  @override
  Future<DashboardOverviewResult?> getOverview() async {
    await Future<void>.delayed(_simulatedDelay);

    switch (scenario) {
      case DashboardMockScenario.empty:
        return null;
      case DashboardMockScenario.offlineNoCache:
        throw const DashboardException(DashboardOfflineFailure());
      case DashboardMockScenario.networkError:
        throw const DashboardException(DashboardNetworkFailure());
      case DashboardMockScenario.repositoryError:
        throw const DashboardException(DashboardUnknownFailure());
      case DashboardMockScenario.normalActive:
        return DashboardOverviewResult(overview: _activeOverview());
      case DashboardMockScenario.newUser:
        return DashboardOverviewResult(overview: _newUserOverview());
      case DashboardMockScenario.recoveryMode:
        return DashboardOverviewResult(overview: _recoveryOverview());
      case DashboardMockScenario.completedMission:
        return DashboardOverviewResult(overview: _completedMissionOverview());
      case DashboardMockScenario.offlineCached:
        return DashboardOverviewResult(
          overview: _activeOverview(),
          isOfflineCache: true,
        );
    }
  }

  static String _greetingFor(DateTime at) {
    if (at.hour < 12) return 'Good morning';
    if (at.hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  WeeklySnapshot _week(
    List<DayCompletionStatus> statuses, {
    String? bestDayLabel,
    String? insight,
  }) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final completed = statuses
        .where((s) => s == DayCompletionStatus.completed)
        .length;
    return WeeklySnapshot(
      days: [
        for (var i = 0; i < 7; i++)
          DaySnapshot(label: labels[i], status: statuses[i]),
      ],
      completionPercent: ((completed / 7) * 100).round(),
      bestDayLabel: bestDayLabel,
      insight: insight,
    );
  }

  DashboardOverview _activeOverview() {
    return DashboardOverview(
      displayName: displayName,
      title: 'Warrior',
      greeting: _greetingFor(_referenceTime),
      currentDay: 26,
      totalChallengeDays: 100,
      currentStreak: 26,
      longestStreak: 41,
      lifetimeXp: 2140,
      currentLevel: 12,
      xpToNextLevel: 860,
      levelProgress: 0.64,
      weeklyCompletionPercent: 80,
      league: const LeaguePreview(
        leagueName: 'Iron League',
        currentPosition: 4,
        promotionZoneDistance: 1,
        weekEndingLabel: 'Ends in 3 days',
      ),
      weeklySnapshot: _week(
        const [
          DayCompletionStatus.completed,
          DayCompletionStatus.completed,
          DayCompletionStatus.completed,
          DayCompletionStatus.partial,
          DayCompletionStatus.completed,
          DayCompletionStatus.none,
          DayCompletionStatus.future,
        ],
        bestDayLabel: 'Wednesday',
        insight: "You're most consistent early in the week.",
      ),
      todayMissionPreview:
          missionOverride ??
          const MissionPreview(
            id: 'mission-001',
            title: '20 Push-ups + Read 1 Dev Article',
            subtitle:
                'Three sets to failure, then one article from your queue.',
            category: 'Fitness + Learning',
            difficulty: MissionDifficulty.moderate,
            estimatedMinutes: 15,
            xpReward: 50,
            status: MissionStatus.notStarted,
            transmissionAvailable: true,
            requiresProof: true,
            characterName: 'The Watcher',
          ),
      recoveryModeActive: false,
      lastUpdatedAt: _referenceTime,
    );
  }

  DashboardOverview _newUserOverview() {
    return DashboardOverview(
      displayName: displayName,
      title: 'Recruit',
      greeting: _greetingFor(_referenceTime),
      currentDay: 0,
      totalChallengeDays: 100,
      currentStreak: 0,
      longestStreak: 0,
      lifetimeXp: 0,
      currentLevel: 1,
      xpToNextLevel: 100,
      levelProgress: 0,
      weeklyCompletionPercent: 0,
      league: const LeaguePreview(
        leagueName: 'Bronze League',
        currentPosition: 0,
        promotionZoneDistance: 0,
        weekEndingLabel: 'Your first week starts now',
      ),
      weeklySnapshot: _week(
        List.filled(7, DayCompletionStatus.future),
        insight: 'Complete your first mission to start the week.',
      ),
      todayMissionPreview:
          missionOverride ??
          const MissionPreview(
            id: 'mission-first',
            title: 'Your First Mission: 10 Push-ups',
            subtitle: 'A short warm-up to open your first streak day.',
            category: 'Fitness',
            difficulty: MissionDifficulty.easy,
            estimatedMinutes: 5,
            xpReward: 20,
            status: MissionStatus.notStarted,
            transmissionAvailable: true,
            requiresProof: false,
            characterName: 'The Watcher',
          ),
      recoveryModeActive: false,
      lastUpdatedAt: _referenceTime,
    );
  }

  DashboardOverview _recoveryOverview() {
    return DashboardOverview(
      displayName: displayName,
      title: 'Warrior',
      greeting: _greetingFor(_referenceTime),
      currentDay: 12,
      totalChallengeDays: 100,
      currentStreak: 0,
      longestStreak: 18,
      lifetimeXp: 640,
      currentLevel: 5,
      xpToNextLevel: 160,
      levelProgress: 0.32,
      weeklyCompletionPercent: 30,
      league: const LeaguePreview(
        leagueName: 'Iron League',
        currentPosition: 9,
        promotionZoneDistance: 4,
        weekEndingLabel: 'Ends in 5 days',
      ),
      weeklySnapshot: _week(const [
        DayCompletionStatus.completed,
        DayCompletionStatus.completed,
        DayCompletionStatus.none,
        DayCompletionStatus.none,
        DayCompletionStatus.future,
        DayCompletionStatus.future,
        DayCompletionStatus.future,
      ], insight: 'A short recovery mission keeps momentum going.'),
      todayMissionPreview:
          missionOverride ??
          const MissionPreview(
            id: 'mission-recovery',
            title: 'Recovery: 5-Minute Walk',
            subtitle: 'One achievable step back into the routine.',
            category: 'Fitness',
            difficulty: MissionDifficulty.easy,
            estimatedMinutes: 5,
            xpReward: 20,
            status: MissionStatus.notStarted,
            transmissionAvailable: true,
            requiresProof: false,
            characterName: 'The Watcher',
          ),
      recoveryModeActive: true,
      lastUpdatedAt: _referenceTime,
    );
  }

  DashboardOverview _completedMissionOverview() {
    final active = _activeOverview();
    return DashboardOverview(
      displayName: active.displayName,
      title: active.title,
      greeting: active.greeting,
      currentDay: active.currentDay,
      totalChallengeDays: active.totalChallengeDays,
      currentStreak: active.currentStreak,
      longestStreak: active.longestStreak,
      lifetimeXp: active.lifetimeXp,
      currentLevel: active.currentLevel,
      xpToNextLevel: active.xpToNextLevel,
      levelProgress: active.levelProgress,
      weeklyCompletionPercent: active.weeklyCompletionPercent,
      league: active.league,
      weeklySnapshot: active.weeklySnapshot,
      todayMissionPreview:
          missionOverride?.copyWith(status: MissionStatus.completed) ??
          const MissionPreview(
            id: 'mission-001',
            title: '20 Push-ups + Read 1 Dev Article',
            subtitle:
                'Three sets to failure, then one article from your queue.',
            category: 'Fitness + Learning',
            difficulty: MissionDifficulty.moderate,
            estimatedMinutes: 15,
            xpReward: 50,
            status: MissionStatus.completed,
            transmissionAvailable: true,
            requiresProof: true,
            characterName: 'The Watcher',
          ),
      recoveryModeActive: false,
      lastUpdatedAt: active.lastUpdatedAt,
    );
  }
}
