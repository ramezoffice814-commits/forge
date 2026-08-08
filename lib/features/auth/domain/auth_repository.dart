import 'entities/auth_session.dart';

/// Auth backend contract. Both [MockAuthRepository] (dev-only, default
/// while no Supabase project exists) and the eventual real
/// `SupabaseAuthRepository` implement this — nothing above the data layer
/// (use cases, presentation) ever knows or cares which one is active.
abstract class AuthRepository {
  /// Emits the current session whenever it changes (sign-in, sign-out,
  /// token refresh, or an external event like an expired refresh token).
  /// `null` means signed out.
  Stream<AuthSession?> authStateChanges();

  Future<AuthSession> signIn({required String email, required String password});

  Future<AuthSession> signUp({
    required String displayName,
    required String email,
    required String password,
  });

  Future<void> signOut();

  /// Reconstructs a previously-persisted session on app start, or returns
  /// `null` if there isn't one. Never requires the password again.
  Future<AuthSession?> restoreSession();

  Future<void> requestPasswordReset(String email);

  Future<void> updatePassword(String newPassword);

  /// Account deletion is a backend/data-retention decision that doesn't
  /// exist yet (see the "out of scope" list) — implementations should
  /// throw [ForgeAuthException] with [NotSupportedYetFailure].
  Future<void> requestAccountDeletion();

  /// Interface surface for later OAuth support. Neither Google nor Apple
  /// sign-in can be implemented without provider credentials that don't
  /// exist yet, so every implementation throws [NotSupportedYetFailure].
  Future<AuthSession> signInWithGoogle();

  Future<AuthSession> signInWithApple();
}
