import 'dart:async';

import '../../../../core/storage/secure_key_value_store.dart';
import '../../domain/auth_failure.dart';
import '../../domain/auth_repository.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_user.dart';
import 'mock_session_codec.dart';

class _MockAccount {
  _MockAccount({
    required this.id,
    required this.displayName,
    required this.email,
    required this.password,
    required this.createdAt,
  });

  final String id;
  String displayName;
  final String email;

  /// In-memory only, for the lifetime of this process — never persisted,
  /// never logged. Restoring a session after a real restart never reads
  /// this field (see [MockAuthRepository.restoreSession]); it's only
  /// needed to validate a subsequent explicit sign-in in the same run.
  String password;
  final DateTime createdAt;
}

/// Development-only auth backend — no network, no real credential storage.
/// Default while [AppConfig.isMock] (no Supabase project configured yet).
///
/// Security notes:
/// - Nothing password-related is ever persisted to disk; only the signed-in
///   *session* (id/displayName/email/avatarUrl/createdAt) is, via
///   [SecureKeyValueStore] — see [MockSessionCodec].
/// - The in-memory account directory (with plaintext passwords, needed to
///   compare a sign-in attempt) resets on every process restart. A known,
///   accepted limitation of a mock backend: sign-in after a real restart
///   only works for the seeded demo account below, since there is no
///   Supabase to actually persist accounts against. Session *restore*
///   (already-signed-in → still signed in after restart) works fully.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._store) {
    _seedDemoAccount();
  }

  static const _sessionKey = 'forge.auth.mock_session';

  final SecureKeyValueStore _store;
  final Map<String, _MockAccount> _accountsByEmail = {};
  final _authStateController = StreamController<AuthSession?>.broadcast();
  int _idCounter = 0;

  void _seedDemoAccount() {
    // Dev-only fixture credential, never a real secret: lets sign-in be
    // exercised (and re-exercised after sign-out) without going through
    // sign-up first.
    _accountsByEmail['demo@forge.app'] = _MockAccount(
      id: 'mock-demo-user',
      displayName: 'Demo Warrior',
      email: 'demo@forge.app',
      password: 'forgepass1',
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  String _nextId() =>
      'mock-${_idCounter++}-${DateTime.now().microsecondsSinceEpoch}';

  AuthUser _userFor(_MockAccount account, {bool onboardingCompleted = true}) {
    return AuthUser(
      id: account.id,
      displayName: account.displayName,
      email: account.email,
      createdAt: account.createdAt,
      onboardingCompleted: onboardingCompleted,
    );
  }

  Future<void> _persist(AuthSession session) {
    return _store.write(_sessionKey, MockSessionCodec.encode(session));
  }

  @override
  Stream<AuthSession?> authStateChanges() => _authStateController.stream;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final account = _accountsByEmail[email];
    if (account == null || account.password != password) {
      throw const ForgeAuthException(InvalidCredentialsFailure());
    }
    final session = AuthSession(
      user: _userFor(account),
      accessToken: 'mock-token-${account.id}',
    );
    await _persist(session);
    _authStateController.add(session);
    return session;
  }

  @override
  Future<AuthSession> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_accountsByEmail.containsKey(email)) {
      throw const ForgeAuthException(EmailAlreadyInUseFailure());
    }
    if (password.length < 8) {
      throw const ForgeAuthException(WeakPasswordFailure());
    }
    final account = _MockAccount(
      id: _nextId(),
      displayName: displayName,
      email: email,
      password: password,
      createdAt: DateTime.now().toUtc(),
    );
    _accountsByEmail[email] = account;
    final session = AuthSession(
      user: _userFor(account),
      accessToken: 'mock-token-${account.id}',
    );
    await _persist(session);
    _authStateController.add(session);
    return session;
  }

  @override
  Future<void> signOut() async {
    await _store.delete(_sessionKey);
    _authStateController.add(null);
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final raw = await _store.read(_sessionKey);
    if (raw == null) return null;
    final session = MockSessionCodec.decode(raw);
    if (session != null) {
      _authStateController.add(session);
    }
    return session;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    // Simulated only — always "succeeds" regardless of whether the email
    // is registered, matching real providers' behavior of never revealing
    // account existence through this endpoint.
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final raw = await _store.read(_sessionKey);
    final session = raw == null ? null : MockSessionCodec.decode(raw);
    if (session == null) {
      throw const ForgeAuthException(NotAuthenticatedFailure());
    }
    final account = _accountsByEmail[session.user.email];
    if (account != null) {
      account.password = newPassword;
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
