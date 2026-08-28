import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../domain/auth_failure.dart';
import '../../domain/auth_repository.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_user.dart';
import 'supabase_auth_error_mapper.dart';

/// Real auth backend, active when `AppConfig.isLive`. Takes an already
/// -initialized [supa.SupabaseClient] via constructor injection — it never
/// touches the `Supabase.instance` singleton itself, so it stays testable
/// and never runs against a client that wasn't safely configured (see
/// `assertAuthRepositoryConfigIsSafe` at the call site).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final supa.SupabaseClient _client;

  AuthUser _toUser(supa.User user) {
    final metadata = user.userMetadata;
    return AuthUser(
      id: user.id,
      displayName:
          (metadata?['display_name'] as String?) ??
          (user.email?.split('@').first ?? 'CAN user'),
      email: user.email ?? '',
      avatarUrl: metadata?['avatar_url'] as String?,
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      // Supabase doesn't track this yet — see item 3 scope notes; treated
      // as complete for any account that reached a real session, since
      // onboarding-gating is handled by the separate device-local flag.
      onboardingCompleted: true,
    );
  }

  AuthSession? _toSession(supa.Session? session) {
    if (session == null) return null;
    return AuthSession(
      user: _toUser(session.user),
      accessToken: session.accessToken,
    );
  }

  @override
  Stream<AuthSession?> authStateChanges() {
    return _client.auth.onAuthStateChange.map(
      (data) => _toSession(data.session),
    );
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final session = _toSession(response.session);
      if (session == null) {
        throw const ForgeAuthException(InvalidCredentialsFailure());
      }
      return session;
    } on supa.AuthException catch (e) {
      throw ForgeAuthException(mapSupabaseAuthError(e));
    }
  }

  @override
  Future<AuthSession> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      final session = _toSession(response.session);
      if (session == null) {
        // Email-confirmation-required projects return a user but no
        // session — there's no session to hand back yet.
        throw const ForgeAuthException(NotAuthenticatedFailure());
      }
      return session;
    } on supa.AuthException catch (e) {
      throw ForgeAuthException(mapSupabaseAuthError(e));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on supa.AuthException catch (e) {
      throw ForgeAuthException(mapSupabaseAuthError(e));
    }
  }

  @override
  Future<AuthSession?> restoreSession() async {
    // supabase_flutter hydrates `currentSession` from its own persisted
    // storage before `Supabase.initialize()` completes — nothing to do
    // here beyond reading it back.
    return _toSession(_client.auth.currentSession);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on supa.AuthException catch (e) {
      throw ForgeAuthException(mapSupabaseAuthError(e));
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(supa.UserAttributes(password: newPassword));
    } on supa.AuthException catch (e) {
      throw ForgeAuthException(mapSupabaseAuthError(e));
    }
  }

  @override
  Future<void> requestAccountDeletion() {
    throw const ForgeAuthException(NotSupportedYetFailure());
  }

  @override
  Future<AuthSession> signInWithGoogle() {
    throw const ForgeAuthException(NotSupportedYetFailure());
  }

  @override
  Future<AuthSession> signInWithApple() {
    throw const ForgeAuthException(NotSupportedYetFailure());
  }
}
