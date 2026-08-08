/// Injected time source — section 10/11 require elapsed time to come from
/// an abstraction, never a bare `DateTime.now()` call scattered through use
/// cases, so tests are deterministic and a future monotonic-clock-backed
/// implementation is a one-line swap.
abstract class MissionClock {
  DateTime now();
}

class SystemMissionClock implements MissionClock {
  const SystemMissionClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
