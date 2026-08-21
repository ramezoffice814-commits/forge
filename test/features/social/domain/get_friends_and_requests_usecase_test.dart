import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/social/data/repositories/in_memory_social_repository.dart';
import 'package:forge/features/social/domain/usecases/accept_friend_request_usecase.dart';
import 'package:forge/features/social/domain/usecases/get_activity_feed_usecase.dart';
import 'package:forge/features/social/domain/usecases/get_friends_usecase.dart';
import 'package:forge/features/social/domain/usecases/get_pending_requests_usecase.dart';
import 'package:forge/features/social/domain/usecases/send_friend_request_usecase.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);
  const userId = 'test-user';
  const mockFriendA = 'mock-social-0';
  const mockFriendB = 'mock-social-1';
  const mockRequester = 'mock-social-2';

  group('GetFriendsUseCase', () {
    test('an empty friend list returns an empty list, not an error', () async {
      final repository = InMemorySocialRepository();
      final result = await GetFriendsUseCase(repository)(userId);
      expect(result, isEmpty);
    });

    test('returns the public profile for each accepted friend', () async {
      final repository = InMemorySocialRepository();
      final send = SendFriendRequestUseCase(repository);
      final accept = AcceptFriendRequestUseCase(repository);

      for (final friendId in [mockFriendA, mockFriendB]) {
        final sent =
            await send(senderId: userId, receiverId: friendId, now: now)
                as SendFriendRequestSent;
        await accept(sent.request.id, now: now);
      }

      final friends = await GetFriendsUseCase(repository)(userId);
      expect(friends.map((p) => p.userId).toSet(), {mockFriendA, mockFriendB});
    });
  });

  group('GetPendingRequestsUseCase', () {
    test('no incoming requests returns an empty list', () async {
      final repository = InMemorySocialRepository();
      final result = await GetPendingRequestsUseCase(repository)(userId);
      expect(result, isEmpty);
    });

    test(
      'an incoming request is paired with the sender\'s public profile',
      () async {
        final repository = InMemorySocialRepository();
        await SendFriendRequestUseCase(repository)(
          senderId: mockRequester,
          receiverId: userId,
          now: now,
        );

        final views = await GetPendingRequestsUseCase(repository)(userId);
        expect(views, hasLength(1));
        expect(views.single.senderProfile.userId, mockRequester);
        expect(views.single.request.receiverId, userId);
      },
    );

    test('outgoing requests never appear as incoming', () async {
      final repository = InMemorySocialRepository();
      await SendFriendRequestUseCase(repository)(
        senderId: userId,
        receiverId: mockRequester,
        now: now,
      );

      final views = await GetPendingRequestsUseCase(repository)(userId);
      expect(views, isEmpty);
    });
  });

  group('GetActivityFeedUseCase', () {
    test('with no friends, the activity feed is empty', () async {
      final repository = InMemorySocialRepository();
      final result = await GetActivityFeedUseCase(repository)(userId);
      expect(result, isEmpty);
    });

    test('shows events only from actual friends, newest first', () async {
      final repository = InMemorySocialRepository();
      final sent =
          await SendFriendRequestUseCase(repository)(
                senderId: userId,
                receiverId: mockFriendA,
                now: now,
              )
              as SendFriendRequestSent;
      await AcceptFriendRequestUseCase(repository)(sent.request.id, now: now);

      final feed = await GetActivityFeedUseCase(repository)(userId);
      expect(feed, isNotEmpty);
      expect(feed.every((e) => e.userId == mockFriendA), isTrue);
      for (var i = 1; i < feed.length; i++) {
        expect(
          feed[i - 1].occurredAt.isAfter(feed[i].occurredAt) ||
              feed[i - 1].occurredAt.isAtSameMomentAs(feed[i].occurredAt),
          isTrue,
        );
      }
    });

    test('a non-friend\'s activity never appears in the feed', () async {
      final repository = InMemorySocialRepository();
      final feed = await GetActivityFeedUseCase(repository)(userId);
      expect(feed.where((e) => e.userId == mockFriendA), isEmpty);
    });
  });
}
