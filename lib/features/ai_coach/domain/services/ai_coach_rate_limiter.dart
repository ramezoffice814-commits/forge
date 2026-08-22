/// Client-side rate limiting (Roadmap Item 14 section 17) — the first,
/// cheapest line of defense against "a chat loop creates uncontrolled
/// API cost." This is *not* the authoritative limit (the `ai-coach` Edge
/// Function enforces its own server-side limit regardless of what the
/// client does — a client can be modified or bypassed entirely), but it
/// keeps a normal UI from ever firing more requests than a person could
/// plausibly want, and gives immediate feedback without a round trip.
class AiCoachRateLimiter {
  AiCoachRateLimiter({
    this.maxRequestsPerWindow = 10,
    this.window = const Duration(minutes: 1),
    DateTime Function() now = DateTime.now,
  }) : _now = now;

  final int maxRequestsPerWindow;
  final Duration window;
  final DateTime Function() _now;

  final List<DateTime> _recentRequests = [];

  /// `true` if a request is allowed right now — callers must call
  /// [record] themselves immediately after actually dispatching one;
  /// this method alone never mutates state, so a caller can check
  /// without committing to sending.
  bool get allowsRequest {
    _evictExpired();
    return _recentRequests.length < maxRequestsPerWindow;
  }

  void record() {
    _evictExpired();
    _recentRequests.add(_now());
  }

  void _evictExpired() {
    final cutoff = _now().subtract(window);
    _recentRequests.removeWhere((t) => t.isBefore(cutoff));
  }
}
