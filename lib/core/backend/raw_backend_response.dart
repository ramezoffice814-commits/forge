import 'package:flutter/foundation.dart';

/// Proof a value genuinely came back from a [BackendClient] call — the
/// actual trust-boundary enforcement mechanism (see
/// `core/security/authoritative_value.dart`'s doc comment for the full
/// chain). The constructor is private to this file; the only public way
/// to obtain an instance is [fromBackendAdapter], a name deliberately
/// chosen to make "I am pretending to be a backend adapter" visible and
/// deliberate at every call site — reserved for actual [BackendClient]
/// implementations (`MockBackendClient` this phase, a Supabase adapter
/// later), never called from domain or presentation code.
@immutable
class RawBackendResponse<T> {
  const RawBackendResponse._({
    required this.payload,
    required this.serverTimestamp,
    required this.confirmationId,
  });

  factory RawBackendResponse.fromBackendAdapter({
    required T payload,
    required DateTime serverTimestamp,
    required String confirmationId,
  }) {
    return RawBackendResponse._(
      payload: payload,
      serverTimestamp: serverTimestamp,
      confirmationId: confirmationId,
    );
  }

  final T payload;
  final DateTime serverTimestamp;
  final String confirmationId;
}
