import 'dart:convert';

import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_user.dart';

/// Encodes/decodes a persisted mock session for [SecureKeyValueStore].
/// Deliberately carries no password or credential material — restoring a
/// session never needs the password again, only sign-in does.
abstract final class MockSessionCodec {
  static String encode(AuthSession session) {
    final user = session.user;
    return jsonEncode({
      'accessToken': session.accessToken,
      'id': user.id,
      'displayName': user.displayName,
      'email': user.email,
      'avatarUrl': user.avatarUrl,
      'createdAt': user.createdAt.toIso8601String(),
      'onboardingCompleted': user.onboardingCompleted,
    });
  }

  static AuthSession? decode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AuthSession(
        accessToken: map['accessToken'] as String,
        user: AuthUser(
          id: map['id'] as String,
          displayName: map['displayName'] as String,
          email: map['email'] as String,
          avatarUrl: map['avatarUrl'] as String?,
          createdAt: DateTime.parse(map['createdAt'] as String),
          onboardingCompleted: map['onboardingCompleted'] as bool,
        ),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
