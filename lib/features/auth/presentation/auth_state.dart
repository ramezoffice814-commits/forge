import 'package:flutter/foundation.dart';

import '../domain/auth_failure.dart';
import '../domain/entities/auth_session.dart';

enum AuthStatus {
  initial,
  restoring,
  unauthenticated,
  authenticating,
  authenticated,
  failure,
}

@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.session,
    this.failure,
    this.pendingEmail,
  });

  final AuthStatus status;
  final AuthSession? session;
  final AuthFailure? failure;

  /// Preserved across a failed sign-in/sign-up attempt so the form can
  /// re-show it without the user retyping — see requirement to "preserve
  /// email after failed sign-in".
  final String? pendingEmail;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && session != null;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    AuthFailure? failure,
    String? pendingEmail,
    bool clearSession = false,
    bool clearFailure = false,
    bool clearPendingEmail = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      failure: clearFailure ? null : (failure ?? this.failure),
      pendingEmail: clearPendingEmail
          ? null
          : (pendingEmail ?? this.pendingEmail),
    );
  }
}
