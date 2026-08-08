/// Everything that can go wrong during auth, deliberately coarse-grained —
/// enough for the UI to pick the right copy and action, never enough to
/// leak backend internals (see [UnknownAuthFailure]).
sealed class AuthFailure {
  const AuthFailure();
}

/// Wrong email/password, or an account that doesn't exist — merged into one
/// failure on purpose, so error copy never confirms which part was wrong.
class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure();
}

class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure();
}

class WeakPasswordFailure extends AuthFailure {
  const WeakPasswordFailure();
}

class NetworkFailure extends AuthFailure {
  const NetworkFailure();
}

class NotAuthenticatedFailure extends AuthFailure {
  const NotAuthenticatedFailure();
}

/// Live mode selected but Supabase URL/anon key are missing or a request
/// couldn't reach a properly configured backend. Never surfaced with
/// internal detail — just "try again later".
class NotConfiguredFailure extends AuthFailure {
  const NotConfiguredFailure();
}

/// For interface surface that exists but isn't wired up yet (OAuth,
/// account-deletion backend) — see [DeleteAccountRequestUseCase].
class NotSupportedYetFailure extends AuthFailure {
  const NotSupportedYetFailure();
}

class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure();
}

/// Thrown by [AuthRepository] implementations; use cases and the
/// presentation layer catch this, never a raw SDK exception.
class ForgeAuthException implements Exception {
  const ForgeAuthException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'ForgeAuthException(${failure.runtimeType})';
}
