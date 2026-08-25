import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/ai_coach/domain/services/ai_coach_rate_limiter.dart';

void main() {
  test('allows requests up to the configured window cap', () {
    var now = DateTime(2026, 1, 1);
    final limiter = AiCoachRateLimiter(maxRequestsPerWindow: 3, now: () => now);

    expect(limiter.allowsRequest, isTrue);
    limiter.record();
    expect(limiter.allowsRequest, isTrue);
    limiter.record();
    expect(limiter.allowsRequest, isTrue);
    limiter.record();
    expect(limiter.allowsRequest, isFalse);
  });

  test('evicts requests once the window elapses', () {
    var now = DateTime(2026, 1, 1);
    final limiter = AiCoachRateLimiter(
      maxRequestsPerWindow: 1,
      window: const Duration(minutes: 1),
      now: () => now,
    );

    limiter.record();
    expect(limiter.allowsRequest, isFalse);

    now = now.add(const Duration(minutes: 2));
    expect(limiter.allowsRequest, isTrue);
  });

  test('allowsRequest never mutates state on its own', () {
    var now = DateTime(2026, 1, 1);
    final limiter = AiCoachRateLimiter(maxRequestsPerWindow: 1, now: () => now);

    expect(limiter.allowsRequest, isTrue);
    expect(limiter.allowsRequest, isTrue);
    expect(limiter.allowsRequest, isTrue);
  });
}
