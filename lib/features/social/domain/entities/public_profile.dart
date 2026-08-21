import 'package:flutter/foundation.dart';

/// The only shape another user is ever allowed to see. Every field here is
/// public-safe by construction — see module privacy rules: never add a
/// field for recovery state, health limitations, private mission history,
/// personal reflections, or private analytics. [competitionSummary] and
/// [league] are precomputed display strings, never raw scoring internals.
@immutable
class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.level,
    required this.title,
    required this.achievementsCount,
    required this.league,
    required this.competitionSummary,
  });

  final String userId;
  final String displayName;

  /// `null` means "show the placeholder avatar" — no real avatar upload
  /// exists yet.
  final String? avatarUrl;

  final int level;
  final String title;
  final int achievementsCount;
  final String league;

  /// A precomputed, provisional display string (e.g. "Rank 3 in Iron
  /// League (preview)") — never a raw score, weekly cap breakdown, or
  /// anything from `CompetitiveScoreEvaluation`.
  final String competitionSummary;
}
