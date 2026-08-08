import 'package:flutter/foundation.dart';

/// The minimum identity profile Forge needs. Deliberately excludes XP,
/// streaks, rank, or any gameplay data — those belong to other features'
/// own models later, kept separate so auth identity and game profile can
/// evolve independently on the backend.
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.createdAt,
    required this.onboardingCompleted,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;
  final bool onboardingCompleted;

  AuthUser copyWith({
    String? displayName,
    String? email,
    String? avatarUrl,
    bool? onboardingCompleted,
  }) {
    return AuthUser(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthUser &&
          other.id == id &&
          other.displayName == displayName &&
          other.email == email &&
          other.avatarUrl == avatarUrl &&
          other.createdAt == createdAt &&
          other.onboardingCompleted == onboardingCompleted);

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    email,
    avatarUrl,
    createdAt,
    onboardingCompleted,
  );
}
