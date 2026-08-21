import 'package:flutter/foundation.dart';

import '../enums/profile_visibility.dart';

@immutable
class ProfileVisibilitySettings {
  const ProfileVisibilitySettings({
    required this.userId,
    required this.visibility,
    required this.updatedAt,
  });

  factory ProfileVisibilitySettings.defaultFor(String userId, DateTime now) {
    return ProfileVisibilitySettings(
      userId: userId,
      visibility: ProfileVisibility.friendsOnly,
      updatedAt: now,
    );
  }

  final String userId;
  final ProfileVisibility visibility;
  final DateTime updatedAt;

  ProfileVisibilitySettings copyWith({
    ProfileVisibility? visibility,
    DateTime? updatedAt,
  }) {
    return ProfileVisibilitySettings(
      userId: userId,
      visibility: visibility ?? this.visibility,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
