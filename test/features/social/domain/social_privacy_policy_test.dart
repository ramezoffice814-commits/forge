import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/social/domain/entities/profile_visibility_settings.dart';
import 'package:forge/features/social/domain/enums/profile_visibility.dart';
import 'package:forge/features/social/domain/policies/social_privacy_policy.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);

  test(
    'the owner can always view their own profile, regardless of visibility',
    () {
      for (final visibility in ProfileVisibility.values) {
        final canView = SocialPrivacyPolicy.canView(
          viewerId: 'u1',
          targetUserId: 'u1',
          settings: ProfileVisibilitySettings(
            userId: 'u1',
            visibility: visibility,
            updatedAt: now,
          ),
          isFriend: false,
        );
        expect(canView, isTrue, reason: visibility.name);
      }
    },
  );

  test('a public profile is visible to anyone', () {
    final canView = SocialPrivacyPolicy.canView(
      viewerId: 'stranger',
      targetUserId: 'u1',
      settings: ProfileVisibilitySettings(
        userId: 'u1',
        visibility: ProfileVisibility.public,
        updatedAt: now,
      ),
      isFriend: false,
    );
    expect(canView, isTrue);
  });

  test('a friends-only profile is visible only to friends', () {
    final settings = ProfileVisibilitySettings(
      userId: 'u1',
      visibility: ProfileVisibility.friendsOnly,
      updatedAt: now,
    );
    expect(
      SocialPrivacyPolicy.canView(
        viewerId: 'friend',
        targetUserId: 'u1',
        settings: settings,
        isFriend: true,
      ),
      isTrue,
    );
    expect(
      SocialPrivacyPolicy.canView(
        viewerId: 'stranger',
        targetUserId: 'u1',
        settings: settings,
        isFriend: false,
      ),
      isFalse,
    );
  });

  test('a private profile is never visible to anyone but the owner', () {
    final settings = ProfileVisibilitySettings(
      userId: 'u1',
      visibility: ProfileVisibility.private,
      updatedAt: now,
    );
    expect(
      SocialPrivacyPolicy.canView(
        viewerId: 'friend',
        targetUserId: 'u1',
        settings: settings,
        isFriend: true,
      ),
      isFalse,
    );
    expect(
      SocialPrivacyPolicy.canView(
        viewerId: 'stranger',
        targetUserId: 'u1',
        settings: settings,
        isFriend: false,
      ),
      isFalse,
    );
  });
}
