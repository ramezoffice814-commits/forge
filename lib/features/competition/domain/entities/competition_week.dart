import 'package:flutter/foundation.dart';

import '../enums/competition_week_status.dart';

/// One ISO-like week within a [SeasonDefinition] — Monday 00:00:00 UTC
/// through the following Monday 00:00:00 UTC, exclusive. See
/// `CompetitionCalendar` for how these are derived from a season's
/// `startsAt`.
@immutable
class CompetitionWeek {
  const CompetitionWeek({
    required this.seasonId,
    required this.weekNumber,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  final String seasonId;

  /// 1-indexed within the season.
  final int weekNumber;

  final DateTime startsAt;
  final DateTime endsAt;
  final CompetitionWeekStatus status;

  bool contains(DateTime instant) {
    final utc = instant.toUtc();
    return !utc.isBefore(startsAt) && utc.isBefore(endsAt);
  }
}
