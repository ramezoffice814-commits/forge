import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/server_clock.dart';

void main() {
  test('SystemClock returns a real, current-ish instant', () {
    const clock = SystemClock();
    final before = DateTime.now();
    final result = clock.now();
    final after = DateTime.now();
    expect(result.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    expect(result.isBefore(after.add(const Duration(seconds: 1))), isTrue);
  });

  test('MockServerClock never changes on its own', () {
    final fixed = DateTime.utc(2026, 8, 10);
    final clock = MockServerClock(fixed);
    expect(clock.now(), fixed);
    expect(clock.now(), fixed);
  });

  test('MockServerClock.advance moves time forward deterministically', () {
    final clock = MockServerClock(DateTime.utc(2026, 8, 10));
    clock.advance(const Duration(hours: 2));
    expect(clock.now(), DateTime.utc(2026, 8, 10, 2));
  });

  test('MockServerClock.setTo jumps to an exact instant', () {
    final clock = MockServerClock(DateTime.utc(2026, 8, 10));
    clock.setTo(DateTime.utc(2027, 1, 1));
    expect(clock.now(), DateTime.utc(2027, 1, 1));
  });
}
