import 'package:flutter/foundation.dart';

import '../enums/season_status.dart';

/// One competitive season. Boundaries are explicit UTC instants (never
/// derived from device locale/timezone) so every participant's week/season
/// windows line up regardless of where they are — see
/// `CompetitionCalendar.weekBoundariesFor`.
@immutable
class SeasonDefinition {
  const SeasonDefinition({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.weekCount,
    required this.scoringVersion,
    required this.leagueRulesVersion,
    required this.promotionRulesVersion,
    required this.active,
  });

  final String id;
  final String name;

  /// UTC instants — deliberately not `DateTime.now()`-relative at the
  /// definition level, so a season's boundaries never silently shift.
  final DateTime startsAt;
  final DateTime endsAt;

  final SeasonStatus status;
  final int weekCount;

  /// Bumped whenever `ForgeCompetitiveScorePolicy`'s formula changes, so a
  /// stored score can always be traced back to the rules that produced it.
  final int scoringVersion;
  final int leagueRulesVersion;
  final int promotionRulesVersion;

  /// Exactly one season should be `active` at a time in mock mode — a
  /// convenience flag so callers don't have to re-derive it from `status`
  /// and `now` at every call site.
  final bool active;
}
