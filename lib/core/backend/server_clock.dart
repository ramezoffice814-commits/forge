/// The one seam between "authoritative time" and wall-clock time.
/// `DateTime.now()` must never be trusted for reward/progression
/// decisions — a device clock can be wrong, changed, or manipulated.
/// Mission rewards, seasons, and competition must eventually read time
/// through this instead (not yet wired into those systems in this phase —
/// see module scope notes).
abstract class ServerClock {
  DateTime now();
}

/// Device wall-clock time — fine for non-authoritative UI purposes only
/// (relative timestamps, "just now" labels, local sorting). Never for a
/// decision a server would need to independently verify.
class SystemClock implements ServerClock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Deterministic, manually-advanced clock for tests — also the shape a
/// future real server-time adapter (an NTP-corrected clock, or a
/// `/time`-endpoint-backed one) will eventually fill in behind this same
/// interface.
class MockServerClock implements ServerClock {
  MockServerClock(DateTime initial) : _current = initial;

  DateTime _current;

  @override
  DateTime now() => _current;

  void advance(Duration duration) => _current = _current.add(duration);

  void setTo(DateTime instant) => _current = instant;
}
