import 'server_clock.dart';

/// A unique id per network attempt — used for tracing/logging, never for
/// idempotency (two retries of the same logical command get *different*
/// request ids but the *same* idempotency key; see
/// [IdempotencyKeyGenerator]).
abstract class RequestIdGenerator {
  String next();
}

/// Deterministic given a fixed [ServerClock] and starting counter — no
/// `Random()`, so tests never need to pattern-match a UUID.
class SequentialRequestIdGenerator implements RequestIdGenerator {
  SequentialRequestIdGenerator({
    this.prefix = 'req',
    this.clock = const SystemClock(),
  });

  final String prefix;
  final ServerClock clock;
  int _counter = 0;

  @override
  String next() {
    final micros = clock.now().microsecondsSinceEpoch;
    final sequence = (_counter++).toString().padLeft(6, '0');
    return '$prefix-$micros-$sequence';
  }
}
