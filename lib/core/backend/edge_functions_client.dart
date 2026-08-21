import 'package:flutter/foundation.dart';

/// Thrown when calling a Supabase Edge Function fails — either a
/// transport-level failure or the function itself returning a non-2xx
/// response. [errorCode] is populated whenever the function returned one
/// of the stable codes documented in `supabase/functions/_shared/
/// errors.ts` (e.g. `invalid_transition`, `stale_sequence`) — callers use
/// it to distinguish an expected business rejection from a genuine
/// internal failure. `null` means the failure couldn't be attributed to
/// a known code (a real network error, a malformed error body, etc.).
@immutable
class EdgeFunctionCallFailure implements Exception {
  const EdgeFunctionCallFailure(
    this.message, {
    this.errorCode,
    this.statusCode,
  });

  final String message;
  final String? errorCode;
  final int? statusCode;

  @override
  String toString() =>
      'EdgeFunctionCallFailure(errorCode: $errorCode, status: $statusCode): $message';
}

/// The one seam [SupabaseBackendClient] depends on for actually invoking
/// a Supabase Edge Function — kept as a narrow interface (rather than a
/// direct `supabase_flutter` dependency scattered through the adapter)
/// so the adapter's response-mapping/trust-boundary logic is testable
/// with a fake implementation and no network access at all.
abstract class EdgeFunctionsClient {
  Future<Map<String, Object?>> invoke(
    String functionName,
    Map<String, Object?> body,
  );
}
