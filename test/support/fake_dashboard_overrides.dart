import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge/features/dashboard/domain/entities/dashboard_overview.dart';
import 'package:forge/features/dashboard/domain/entities/league_preview.dart';
import 'package:forge/features/dashboard/domain/entities/mission_preview.dart';
import 'package:forge/features/dashboard/domain/entities/weekly_snapshot.dart';
import 'package:forge/features/dashboard/presentation/dashboard_notifier.dart';
import 'package:forge/features/dashboard/presentation/dashboard_state.dart';

/// A plausible, deterministic [DashboardOverview] for tests that need one
/// without going through the real (delayed) mock repository fetch.
DashboardOverview buildTestDashboardOverview({
  String displayName = 'Test User',
  MissionStatus missionStatus = MissionStatus.notStarted,
}) {
  return DashboardOverview(
    displayName: displayName,
    title: 'Warrior',
    greeting: 'Good morning',
    currentDay: 5,
    totalChallengeDays: 100,
    currentStreak: 5,
    longestStreak: 5,
    lifetimeXp: 100,
    currentLevel: 2,
    xpToNextLevel: 100,
    levelProgress: 0.5,
    weeklyCompletionPercent: 50,
    league: const LeaguePreview(
      leagueName: 'Iron League',
      currentPosition: 1,
      promotionZoneDistance: 1,
      weekEndingLabel: 'Ends in 3 days',
    ),
    weeklySnapshot: WeeklySnapshot(
      days: const [
        DaySnapshot(label: 'M', status: DayCompletionStatus.completed),
        DaySnapshot(label: 'T', status: DayCompletionStatus.completed),
        DaySnapshot(label: 'W', status: DayCompletionStatus.none),
        DaySnapshot(label: 'T', status: DayCompletionStatus.future),
        DaySnapshot(label: 'F', status: DayCompletionStatus.future),
        DaySnapshot(label: 'S', status: DayCompletionStatus.future),
        DaySnapshot(label: 'S', status: DayCompletionStatus.future),
      ],
      completionPercent: 50,
    ),
    todayMissionPreview: MissionPreview(
      id: 'mission-test',
      title: 'Test Mission',
      subtitle: 'A test mission.',
      category: 'Fitness',
      difficulty: MissionDifficulty.easy,
      estimatedMinutes: 5,
      xpReward: 10,
      status: missionStatus,
      transmissionAvailable: true,
      requiresProof: false,
      characterName: 'The Watcher',
    ),
    recoveryModeActive: false,
    lastUpdatedAt: DateTime.utc(2026, 8, 5),
  );
}

class FakeDashboardPopulatedNotifier extends DashboardNotifier {
  FakeDashboardPopulatedNotifier(this._overview);

  final DashboardOverview _overview;

  @override
  DashboardState build() => DashboardPopulated(_overview);
}

class FakeDashboardLoadingNotifier extends DashboardNotifier {
  @override
  DashboardState build() => const DashboardLoading();
}

/// Overrides `dashboardNotifierProvider` to resolve synchronously to
/// [DashboardPopulated] — needed by any test that mounts
/// `DailyTransmissionPage` directly, since in the real app the page is only
/// reachable once the Dashboard has already populated (the mission card
/// that opens it doesn't render otherwise).
List<Override> dashboardPopulatedOverrides({DashboardOverview? overview}) => [
  dashboardNotifierProvider.overrideWith(
    () => FakeDashboardPopulatedNotifier(
      overview ?? buildTestDashboardOverview(),
    ),
  ),
];
