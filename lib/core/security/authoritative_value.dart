import 'package:flutter/foundation.dart';

import '../backend/raw_backend_response.dart';
import 'data_authority.dart';

/// Wraps any value that might eventually need server confirmation, so its
/// trust level travels with it rather than living in a separate bool/enum
/// callers can forget to check.
///
/// `sealed` means every subtype must live in this file — no other file
/// can declare a fourth variant that, say, claims
/// [DataAuthority.serverConfirmed] without actually going through
/// [ServerConfirmedValue]'s constructor chain. That chain is the real
/// enforcement: [ServerConfirmedValue]'s constructor is private to this
/// file, and its one public factory,
/// [ServerConfirmedValue.fromServerResponse], requires a
/// [RawBackendResponse] — which itself can only be produced by an actual
/// [BackendClient] adapter (see that class's own doc comment). A
/// [ProvisionalValue] can never be silently upgraded: there is no method
/// on this class that turns one into a [ServerConfirmedValue] without a
/// real backend round trip in between.
@immutable
sealed class AuthoritativeValue<T> {
  const AuthoritativeValue(this.value);

  final T value;

  DataAuthority get authority;
}

/// A value that never leaves this device and was never meant to.
class LocalOnlyValue<T> extends AuthoritativeValue<T> {
  const LocalOnlyValue(super.value);

  @override
  DataAuthority get authority => DataAuthority.localOnly;
}

/// A local preview/estimate — safe to display (clearly labeled as such),
/// never safe to treat as final.
class ProvisionalValue<T> extends AuthoritativeValue<T> {
  const ProvisionalValue(super.value, {this.reasons = const []});

  /// Short, human-readable notes on how this preview was derived — purely
  /// for UI/debugging explainability, never load-bearing.
  final List<String> reasons;

  @override
  DataAuthority get authority => DataAuthority.provisional;
}

/// A value confirmed by an actual backend response — the only variant
/// that may be treated as final.
class ServerConfirmedValue<T> extends AuthoritativeValue<T> {
  const ServerConfirmedValue._(
    super.value,
    this.serverTimestamp,
    this.confirmationId,
  );

  /// The one legitimate way to construct a confirmed value — requires a
  /// [RawBackendResponse], which only a real [BackendClient] adapter can
  /// produce. There is deliberately no factory that takes a plain [T] and
  /// a `bool trustMe`.
  factory ServerConfirmedValue.fromServerResponse(
    RawBackendResponse<T> response,
  ) {
    return ServerConfirmedValue._(
      response.payload,
      response.serverTimestamp,
      response.confirmationId,
    );
  }

  final DateTime serverTimestamp;
  final String confirmationId;

  @override
  DataAuthority get authority => DataAuthority.serverConfirmed;
}
