import '../entities/competition_week.dart';
import '../entities/season_definition.dart';
import '../enums/competition_week_status.dart';

/// Deterministic, UTC-only week/season boundary math — the one place that
/// computes them, so device locale/timezone can never silently shift a
/// scoring window (spec section 4).
abstract final class CompetitionCalendar {
  /// Truncates [instant] to the start of its UTC calendar day.
  static DateTime _startOfUtcDay(DateTime instant) {
    final utc = instant.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  /// Monday 00:00:00 UTC of the week containing [instant].
  static DateTime startOfIsoWeek(DateTime instant) {
    final day = _startOfUtcDay(instant);
    // DateTime.weekday: Monday = 1 ... Sunday = 7.
    return day.subtract(Duration(days: day.weekday - 1));
  }

  /// Builds every [CompetitionWeek] for [season], numbered 1..weekCount,
  /// each exactly 7 days starting from the season's own week-aligned start.
  static List<CompetitionWeek> weeksFor(SeasonDefinition season, DateTime now) {
    final seasonWeekStart = startOfIsoWeek(season.startsAt);
    final nowUtc = now.toUtc();

    return List.generate(season.weekCount, (index) {
      final weekNumber = index + 1;
      final startsAt = seasonWeekStart.add(Duration(days: 7 * index));
      final endsAt = startsAt.add(const Duration(days: 7));

      final status = nowUtc.isBefore(startsAt)
          ? CompetitionWeekStatus.upcoming
          : nowUtc.isBefore(endsAt)
          ? CompetitionWeekStatus.active
          : CompetitionWeekStatus.completed;

      return CompetitionWeek(
        seasonId: season.id,
        weekNumber: weekNumber,
        startsAt: startsAt,
        endsAt: endsAt,
        status: status,
      );
    });
  }

  /// The week [now] falls into, or `null` if [now] is outside the season's
  /// span entirely.
  static CompetitionWeek? currentWeekFor(
    SeasonDefinition season,
    DateTime now,
  ) {
    final weeks = weeksFor(season, now);
    for (final week in weeks) {
      if (week.contains(now)) return week;
    }
    return null;
  }
}
