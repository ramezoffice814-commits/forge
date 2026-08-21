import '../entities/profile_visibility_settings.dart';
import '../enums/profile_visibility.dart';

/// The single gate every public-profile read goes through. Never bypassed:
/// `GetPublicProfileUseCase` calls this before returning anything, so a
/// private profile's data can never leak through a code path that forgot
/// to check visibility.
abstract final class SocialPrivacyPolicy {
  static bool canView({
    required String viewerId,
    required String targetUserId,
    required ProfileVisibilitySettings settings,
    required bool isFriend,
  }) {
    if (viewerId == targetUserId) return true;

    return switch (settings.visibility) {
      ProfileVisibility.public => true,
      ProfileVisibility.friendsOnly => isFriend,
      ProfileVisibility.private => false,
    };
  }
}
