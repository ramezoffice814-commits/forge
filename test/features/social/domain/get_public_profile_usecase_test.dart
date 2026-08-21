import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/competition/data/repositories/in_memory_competition_repository.dart';
import 'package:forge/features/progression/data/local/in_memory_progression_repository.dart';
import 'package:forge/features/social/data/repositories/in_memory_social_repository.dart';
import 'package:forge/features/social/domain/entities/profile_visibility_settings.dart';
import 'package:forge/features/social/domain/enums/friend_action_failure_reason.dart';
import 'package:forge/features/social/domain/enums/profile_visibility.dart';
import 'package:forge/features/social/domain/usecases/accept_friend_request_usecase.dart';
import 'package:forge/features/social/domain/usecases/get_public_profile_usecase.dart';
import 'package:forge/features/social/domain/usecases/send_friend_request_usecase.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);
  const viewerId = 'test-user';
  const mockUserId = 'mock-social-0';

  GetPublicProfileUseCase buildUseCase(InMemorySocialRepository social) {
    return GetPublicProfileUseCase(
      social,
      InMemoryProgressionRepository(),
      InMemoryCompetitionRepository(),
    );
  }

  test('a stranger cannot view a mock user\'s profile by default '
      '(default visibility is friends-only, not public)', () async {
    final social = InMemorySocialRepository();
    final result = await buildUseCase(social)(
      viewerId: viewerId,
      targetUserId: mockUserId,
      targetDisplayName: 'Viewer',
    );
    expect(result, isA<PublicProfileHidden>());
  });

  test(
    'a mock user with public visibility is viewable by a stranger',
    () async {
      final social = InMemorySocialRepository();
      await social.setVisibilitySettings(
        ProfileVisibilitySettings(
          userId: mockUserId,
          visibility: ProfileVisibility.public,
          updatedAt: now,
        ),
      );

      final result = await buildUseCase(social)(
        viewerId: viewerId,
        targetUserId: mockUserId,
        targetDisplayName: 'Viewer',
      );
      expect(result, isA<PublicProfileAvailable>());
      expect((result as PublicProfileAvailable).profile.userId, mockUserId);
    },
  );

  test('a user can always view their own profile', () async {
    final social = InMemorySocialRepository();
    await social.setVisibilitySettings(
      ProfileVisibilitySettings(
        userId: viewerId,
        visibility: ProfileVisibility.private,
        updatedAt: now,
      ),
    );

    final result = await buildUseCase(social)(
      viewerId: viewerId,
      targetUserId: viewerId,
      targetDisplayName: 'Me',
    );
    expect(result, isA<PublicProfileAvailable>());
  });

  test('own profile fields come only from progression/competition public '
      'state — level, title, achievements count, league', () async {
    final social = InMemorySocialRepository();
    final result = await buildUseCase(social)(
      viewerId: viewerId,
      targetUserId: viewerId,
      targetDisplayName: 'Me',
    );
    final profile = (result as PublicProfileAvailable).profile;

    expect(profile.level, greaterThanOrEqualTo(1));
    expect(profile.achievementsCount, greaterThanOrEqualTo(0));
    expect(profile.league, isNotEmpty);
    expect(profile.competitionSummary, isNotEmpty);
  });

  test('a friends-only mock profile is hidden from a non-friend', () async {
    final social = InMemorySocialRepository();
    await social.setVisibilitySettings(
      ProfileVisibilitySettings(
        userId: mockUserId,
        visibility: ProfileVisibility.friendsOnly,
        updatedAt: now,
      ),
    );

    final result = await buildUseCase(social)(
      viewerId: viewerId,
      targetUserId: mockUserId,
      targetDisplayName: 'Viewer',
    );
    expect(result, isA<PublicProfileHidden>());
    expect(
      (result as PublicProfileHidden).reason,
      FriendActionFailureReason.profileNotVisible,
    );
  });

  test(
    'a friends-only mock profile becomes visible once actually friends',
    () async {
      final social = InMemorySocialRepository();
      await social.setVisibilitySettings(
        ProfileVisibilitySettings(
          userId: mockUserId,
          visibility: ProfileVisibility.friendsOnly,
          updatedAt: now,
        ),
      );

      final sent =
          await SendFriendRequestUseCase(social)(
                senderId: viewerId,
                receiverId: mockUserId,
                now: now,
              )
              as SendFriendRequestSent;
      await AcceptFriendRequestUseCase(social)(sent.request.id, now: now);

      final result = await buildUseCase(social)(
        viewerId: viewerId,
        targetUserId: mockUserId,
        targetDisplayName: 'Viewer',
      );
      expect(result, isA<PublicProfileAvailable>());
    },
  );

  test('a private profile is hidden even from friends', () async {
    final social = InMemorySocialRepository();
    await social.setVisibilitySettings(
      ProfileVisibilitySettings(
        userId: mockUserId,
        visibility: ProfileVisibility.private,
        updatedAt: now,
      ),
    );

    final sent =
        await SendFriendRequestUseCase(social)(
              senderId: viewerId,
              receiverId: mockUserId,
              now: now,
            )
            as SendFriendRequestSent;
    await AcceptFriendRequestUseCase(social)(sent.request.id, now: now);

    final result = await buildUseCase(social)(
      viewerId: viewerId,
      targetUserId: mockUserId,
      targetDisplayName: 'Viewer',
    );
    expect(result, isA<PublicProfileHidden>());
  });
}
