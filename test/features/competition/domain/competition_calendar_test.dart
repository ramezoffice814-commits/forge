import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/domain/entities/season_definition.dart';
import 'package:forge/features/competition/domain/enums/season_status.dart';
import 'package:forge/features/competition/domain/policies/competition_calendar.dart';

SeasonDefinition _season({required DateTime startsAt, int weekCount = 8}) {
  return SeasonDefinition(
    id: 'season-1',
    name: 'Season 1',
    startsAt: startsAt,
    endsAt: startsAt.add(Duration(days: 7 * weekCount)),
    status: SeasonStatus.active,
    weekCount: weekCount,
    scoringVersion: 1,
    leagueRulesVersion: 1,
    promotionRulesVersion: 1,
    active: true,
  );
}

void main() {
  test('startOfIsoWeek always returns a Monday at midnight UTC', () {
    for (final instant in [
      DateTime.utc(2026, 8, 3), // Monday
      DateTime.utc(2026, 8, 5), // Wednesday
      DateTime.utc(2026, 8, 9), // Sunday
    ]) {
      final weekStart = CompetitionCalendar.startOfIsoWeek(instant);
      expect(weekStart.weekday, DateTime.monday);
      expect(weekStart.hour, 0);
      expect(weekStart.minute, 0);
    }
  });

  test('weeksFor builds exactly weekCount consecutive 7-day weeks', () {
    final season = _season(startsAt: DateTime.utc(2026, 8, 3));
    final weeks = CompetitionCalendar.weeksFor(
      season,
      DateTime.utc(2026, 8, 3),
    );
    expect(weeks.length, 8);
    for (var i = 0; i < weeks.length; i++) {
      expect(weeks[i].weekNumber, i + 1);
      expect(
        weeks[i].endsAt.difference(weeks[i].startsAt),
        const Duration(days: 7),
      );
      if (i > 0) expect(weeks[i].startsAt, weeks[i - 1].endsAt);
    }
  });

  test('currentWeekFor finds the week containing "now"', () {
    final season = _season(startsAt: DateTime.utc(2026, 8, 3));
    final week = CompetitionCalendar.currentWeekFor(
      season,
      DateTime.utc(2026, 8, 12), // within week 2 (Aug 10-17)
    );
    expect(week?.weekNumber, 2);
  });

  test('currentWeekFor returns null once now is past the whole season', () {
    final season = _season(startsAt: DateTime.utc(2026, 8, 3), weekCount: 2);
    final week = CompetitionCalendar.currentWeekFor(
      season,
      DateTime.utc(2027, 1, 1),
    );
    expect(week, isNull);
  });

  test(
    'device-local time is never consulted — only the UTC instant matters',
    () {
      // A non-UTC DateTime with the same instant must resolve identically.
      final season = _season(startsAt: DateTime.utc(2026, 8, 3));
      final utcNow = DateTime.utc(2026, 8, 5, 12);
      final localEquivalent = utcNow.toLocal();
      expect(
        CompetitionCalendar.currentWeekFor(season, utcNow)?.weekNumber,
        CompetitionCalendar.currentWeekFor(season, localEquivalent)?.weekNumber,
      );
    },
  );
}
