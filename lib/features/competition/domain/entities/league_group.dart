import 'package:flutter/foundation.dart';

@immutable
class LeagueGroup {
  const LeagueGroup({
    required this.groupId,
    required this.seasonId,
    required this.weekNumber,
    required this.leagueId,
    required this.participantIds,
    required this.maxSize,
    required this.createdAt,
  });

  final String groupId;
  final String seasonId;
  final int weekNumber;
  final String leagueId;

  /// Stable membership for the whole week once created — a week's
  /// leaderboard is always ranked within one fixed group, never
  /// re-shuffled mid-week.
  final List<String> participantIds;

  final int maxSize;
  final DateTime createdAt;
}
