import 'package:flutter/foundation.dart';

import 'auth_user.dart';

/// An authenticated session: the user plus an opaque access token. Forge
/// never inspects or parses the token — only the repository that issued it
/// (mock or Supabase) knows what it means.
@immutable
class AuthSession {
  const AuthSession({required this.user, required this.accessToken});

  final AuthUser user;
  final String accessToken;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthSession &&
          other.user == user &&
          other.accessToken == accessToken);

  @override
  int get hashCode => Object.hash(user, accessToken);
}
