import '../domain/auth_failure.dart';

/// Maps each [AuthFailure] to user-facing copy. Every *known* failure gets
/// a specific, non-shaming message; only [UnknownAuthFailure] — genuinely
/// unclassified — falls back to a generic one.
String authFailureMessage(AuthFailure failure) {
  return switch (failure) {
    InvalidCredentialsFailure() =>
      "That email or password isn't right. Try again, or reset your password.",
    EmailAlreadyInUseFailure() =>
      'An account with that email already exists. Try signing in instead.',
    WeakPasswordFailure() => 'Use at least 8 characters.',
    NetworkFailure() => "You're offline. Check your connection and try again.",
    NotAuthenticatedFailure() => 'Please sign in to continue.',
    NotConfiguredFailure() =>
      "Sign-in isn't available right now. Please try again later.",
    NotSupportedYetFailure() => "This isn't available yet.",
    UnknownAuthFailure() => 'Something went wrong. Please try again.',
  };
}
