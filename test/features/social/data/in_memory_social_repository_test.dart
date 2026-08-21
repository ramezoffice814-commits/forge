import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/social/data/mock/mock_social_catalog.dart';
import 'package:forge/features/social/data/repositories/in_memory_social_repository.dart';
import 'package:forge/features/social/domain/entities/friend_request.dart';
import 'package:forge/features/social/domain/entities/friendship.dart';
import 'package:forge/features/social/domain/entities/profile_visibility_settings.dart';
import 'package:forge/features/social/domain/enums/friend_request_status.dart';
import 'package:forge/features/social/domain/enums/profile_visibility.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);

  test('getMockPublicProfile returns null for an unknown user id', () async {
    final repository = InMemorySocialRepository();
    expect(await repository.getMockPublicProfile('not-a-real-id'), isNull);
  });

  test(
    'getMockPublicProfile returns a stable profile for a known mock user',
    () async {
      final repository = InMemorySocialRepository();
      final first = await repository.getMockPublicProfile('mock-social-0');
      final second = await repository.getMockPublicProfile('mock-social-0');
      expect(first, isNotNull);
      expect(first!.userId, second!.userId);
      expect(first.displayName, second.displayName);
    },
  );

  test('every mock user id in the catalog resolves to a profile', () async {
    final repository = InMemorySocialRepository();
    for (final id in MockSocialCatalog.mockUserIds) {
      expect(await repository.getMockPublicProfile(id), isNotNull, reason: id);
    }
  });

  test('activityFeedFor aggregates events across multiple user ids', () async {
    final repository = InMemorySocialRepository();
    final events = await repository.activityFeedFor([
      'mock-social-0',
      'mock-social-1',
    ]);
    expect(events, isNotEmpty);
    expect(events.map((e) => e.userId).toSet(), {
      'mock-social-0',
      'mock-social-1',
    });
  });

  test('activityFeedFor an empty user list returns no events', () async {
    final repository = InMemorySocialRepository();
    expect(await repository.activityFeedFor(const []), isEmpty);
  });

  test('getVisibilitySettings defaults to friends-only for a user who '
      'never set one', () async {
    final repository = InMemorySocialRepository();
    final settings = await repository.getVisibilitySettings('fresh-user');
    expect(settings.visibility, ProfileVisibility.friendsOnly);
  });

  test('setVisibilitySettings persists and is read back', () async {
    final repository = InMemorySocialRepository();
    await repository.setVisibilitySettings(
      ProfileVisibilitySettings(
        userId: 'u1',
        visibility: ProfileVisibility.public,
        updatedAt: now,
      ),
    );
    final settings = await repository.getVisibilitySettings('u1');
    expect(settings.visibility, ProfileVisibility.public);
  });

  test('createRequest then getRequestById round-trips', () async {
    final repository = InMemorySocialRepository();
    final request = FriendRequest(
      id: 'r1',
      senderId: 'a',
      receiverId: 'b',
      status: FriendRequestStatus.pending,
      createdAt: now,
    );
    await repository.createRequest(request);
    final fetched = await repository.getRequestById('r1');
    expect(fetched?.id, 'r1');
  });

  test(
    'existingRequestBetween finds a request regardless of direction',
    () async {
      final repository = InMemorySocialRepository();
      await repository.createRequest(
        FriendRequest(
          id: 'r1',
          senderId: 'a',
          receiverId: 'b',
          status: FriendRequestStatus.pending,
          createdAt: now,
        ),
      );
      expect(await repository.existingRequestBetween('a', 'b'), isNotNull);
      expect(await repository.existingRequestBetween('b', 'a'), isNotNull);
      expect(await repository.existingRequestBetween('a', 'c'), isNull);
    },
  );

  test(
    'clearForUser wipes requests, friendships, and visibility settings',
    () async {
      final repository = InMemorySocialRepository();
      await repository.createRequest(
        FriendRequest(
          id: 'r1',
          senderId: 'a',
          receiverId: 'b',
          status: FriendRequestStatus.pending,
          createdAt: now,
        ),
      );
      await repository.createFriendship(
        Friendship(userId: 'a', friendId: 'c', createdAt: now),
      );
      await repository.setVisibilitySettings(
        ProfileVisibilitySettings(
          userId: 'a',
          visibility: ProfileVisibility.public,
          updatedAt: now,
        ),
      );

      repository.clearForUser('a');

      expect(await repository.incomingRequestsFor('b'), isEmpty);
      expect(await repository.friendshipsFor('a'), isEmpty);
      final settings = await repository.getVisibilitySettings('a');
      // Default (friends-only), since the explicit setting was cleared.
      expect(settings.visibility, ProfileVisibility.friendsOnly);
    },
  );
}
