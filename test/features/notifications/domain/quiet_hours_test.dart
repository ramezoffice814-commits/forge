import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/notifications/domain/entities/quiet_hours.dart';

void main() {
  group('disabled', () {
    test('is never quiet, regardless of the time', () {
      const quietHours = QuietHours(
        enabled: false,
        startMinute: 1350,
        endMinute: 420,
      );
      expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 23, 0)), isFalse);
      expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 3, 0)), isFalse);
      expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 12, 0)), isFalse);
    });
  });

  group('same-day window (e.g. 13:00 -> 17:00)', () {
    const quietHours = QuietHours(
      enabled: true,
      startMinute: 780,
      endMinute: 1020,
    );

    test('is quiet strictly inside the window', () {
      expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 15, 0)), isTrue);
    });

    test('is quiet at the exact start minute (inclusive)', () {
      expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 13, 0)), isTrue);
    });

    test('is not quiet at the exact end minute (exclusive)', () {
      expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 17, 0)), isFalse);
    });

    test('is not quiet before start or after end', () {
      expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 12, 59)), isFalse);
      expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 20, 0)), isFalse);
    });
  });

  group('overnight window (22:30 -> 07:00) — must wrap correctly across '
      'midnight', () {
    const quietHours = QuietHours(
      enabled: true,
      startMinute: 1350,
      endMinute: 420,
    );

    test('is quiet late at night, at/after the start minute', () {
      expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 22, 30)), isTrue);
      expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 23, 59)), isTrue);
    });

    test('is quiet just after midnight, before the end minute', () {
      expect(quietHours.isQuietAt(DateTime(2026, 8, 26, 0, 0)), isTrue);
      expect(quietHours.isQuietAt(DateTime(2026, 8, 26, 6, 59)), isTrue);
    });

    test('is not quiet exactly at the end minute (exclusive) or later in '
        'the morning', () {
      expect(quietHours.isQuietAt(DateTime(2026, 8, 26, 7, 0)), isFalse);
      expect(quietHours.isQuietAt(DateTime(2026, 8, 26, 12, 0)), isFalse);
    });

    test('is not quiet in the middle of the day', () {
      expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 14, 0)), isFalse);
    });

    test('is not quiet just before the start minute in the evening', () {
      expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 22, 29)), isFalse);
    });
  });

  group('zero-width window (start == end)', () {
    const quietHours = QuietHours(
      enabled: true,
      startMinute: 600,
      endMinute: 600,
    );

    test(
      'is treated as always-quiet rather than never-quiet, deterministically',
      () {
        expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 0, 0)), isTrue);
        expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 10, 0)), isTrue);
        expect(quietHours.isQuietAt(DateTime(2026, 8, 25, 23, 59)), isTrue);
      },
    );
  });

  group('nextEligibleTime (Roadmap Item 17 section 9 — scheduling defer)', () {
    test('a candidate outside quiet hours is returned unchanged', () {
      const quietHours = QuietHours(
        enabled: true,
        startMinute: 1350,
        endMinute: 420,
      );
      final candidate = DateTime(2026, 8, 25, 12, 0);
      expect(quietHours.nextEligibleTime(candidate), candidate);
    });

    test('disabled quiet hours never defer anything', () {
      const quietHours = QuietHours(
        enabled: false,
        startMinute: 1350,
        endMinute: 420,
      );
      final candidate = DateTime(2026, 8, 25, 23, 0);
      expect(quietHours.nextEligibleTime(candidate), candidate);
    });

    test('a same-day window defers to end-of-window on the same day', () {
      const quietHours = QuietHours(
        enabled: true,
        startMinute: 780, // 13:00
        endMinute: 1020, // 17:00
      );
      final candidate = DateTime(2026, 8, 25, 15, 0);
      expect(
        quietHours.nextEligibleTime(candidate),
        DateTime(2026, 8, 25, 17, 0),
      );
    });

    test('an overnight window (22:30 -> 07:00) hit late at night defers to '
        '07:00 the next morning', () {
      const quietHours = QuietHours(
        enabled: true,
        startMinute: 1350,
        endMinute: 420,
      );
      final candidate = DateTime(2026, 8, 25, 23, 0);
      expect(
        quietHours.nextEligibleTime(candidate),
        DateTime(2026, 8, 26, 7, 0),
      );
    });

    test('an overnight window hit just after midnight defers to 07:00 that '
        'same morning, not the following day', () {
      const quietHours = QuietHours(
        enabled: true,
        startMinute: 1350,
        endMinute: 420,
      );
      final candidate = DateTime(2026, 8, 26, 2, 0);
      expect(
        quietHours.nextEligibleTime(candidate),
        DateTime(2026, 8, 26, 7, 0),
      );
    });
  });
}
