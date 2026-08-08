import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../domain/auth_failure.dart';

/// Maps a raw `gotrue`/`supabase_flutter` exception to Forge's own
/// [AuthFailure] — the only place SDK error shapes are allowed to leak
/// into. Unmapped or unrecognized errors become [UnknownAuthFailure]
/// rather than surfacing SDK internals to the UI.
AuthFailure mapSupabaseAuthError(Object error) {
  if (error is supa.AuthWeakPasswordException) {
    return const WeakPasswordFailure();
  }
  if (error is supa.AuthRetryableFetchException) {
    return const NetworkFailure();
  }
  if (error is supa.AuthSessionMissingException) {
    return const NotAuthenticatedFailure();
  }
  if (error is supa.AuthApiException) {
    switch (error.code) {
      case 'email_exists':
      case 'user_already_exists':
        return const EmailAlreadyInUseFailure();
      case 'weak_password':
        return const WeakPasswordFailure();
      case 'session_missing':
      case 'session_not_found':
        return const NotAuthenticatedFailure();
    }
    // Supabase's password-grant 400 for a wrong email/password doesn't
    // carry a structured `code` — this is the common case for sign-in.
    if (error.statusCode == '400') {
      return const InvalidCredentialsFailure();
    }
    return const UnknownAuthFailure();
  }
  return const UnknownAuthFailure();
}
