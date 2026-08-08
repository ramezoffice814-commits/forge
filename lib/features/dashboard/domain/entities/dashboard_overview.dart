import 'package:flutter/foundation.dart';

import 'league_preview.dart';
import 'mission_preview.dart';
import 'weekly_snapshot.dart';

/// Everything the Home dashboard needs to render, in one shot. No field is
/// ever computed inside a widget — including [levelProgress], which the
/// spec's suggested model doesn't list but the discipline-progress ring
/// needs as a plain 0–1 fraction (deriving it from `lifetimeXp`/
/// `xpToNextLevel` would require level-threshold math the UI has no
/// business doing).
@immutable
class DashboardOverview {
  const DashboardOverview({
    required this.displayName,
    required this.title,
    required this.greeting,
    required this.currentDay,
    required this.totalChallengeDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.lifetimeXp,
    required this.currentLevel,
    required this.xpToNextLevel,
    required this.levelProgress,
    required this.weeklyCompletionPercent,
    required this.league,
    required this.weeklySnapshot,
    required this.todayMissionPreview,
    required this.recoveryModeActive,
    required this.lastUpdatedAt,
    this.avatarUrl,
  });

  final String displayName;
  final String? avatarUrl;

  /// e.g. "Warrior" — shown next to the name in the header.
  final String title;
  final String greeting;

  final int currentDay;
  final int totalChallengeDays;
  final int currentStreak;
  final int longestStreak;

  final int lifetimeXp;
  final int currentLevel;
  final int xpToNextLevel;

  /// 0–1. Precomputed — see class doc.
  final double levelProgress;

  /// 0–100.
  final int weeklyCompletionPercent;

  final LeaguePreview league;
  final WeeklySnapshot weeklySnapshot;
  final MissionPreview todayMissionPreview;
  final bool recoveryModeActive;
  final DateTime lastUpdatedAt;
}
