import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/social/data/repositories/in_memory_social_repository.dart';
import 'package:forge/features/social/domain/entities/friendship.dart';
import 'package:forge/features/social/domain/enums/friend_action_failure_reason.dart';
import 'package:forge/features/social/domain/enums/friend_request_status.dart';
import 'package:forge/features/social/domain/usecases/accept_friend_request_usecase.dart';
import 'package:forge/features/social/domain/usecases/reject_friend_request_usecase.dart';
import 'package:forge/features/social/domain/usecases/remove_friend_usecase.dart';
import 'package:forge/features/social/domain/usecases/respond_to_friend_request_result.dart';
import 'package:forge/features/social/domain/usecases/send_friend_request_usecase.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);

  group('SendFriendRequestUseCase', () {
    test('a normal request between two different users succeeds', () async {
      final repository = InMemorySocialRepository();
      final useCase = SendFriendRequestUseCase(repository);

      final result = await useCase(senderId: 'a', receiverId: 'b', now: now);

      expect(result, isA<SendFriendRequestSent>());
      final sent = result as SendFriendRequestSent;
      expect(sent.request.status, FriendRequestStatus.pending);
      expect(sent.request.senderId, 'a');
      expect(sent.request.receiverId, 'b');
    });

    test('a self-request is blocked, never sent', () async {
      final repository = InMemorySocialRepository();
      final useCase = SendFriendRequestUseCase(repository);

      final result = await useCase(senderId: 'a', receiverId: 'a', now: now);

      expect(result, isA<SendFriendRequestBlocked>());
      expect(
        (result as SendFriendRequestBlocked).reason,
        FriendActionFailureReason.selfRequest,
      );
    });

    test('a duplicate pending request is blocked', () async {
      final repository = InMemorySocialRepository();
      final useCase = SendFriendRequestUseCase(repository);

      await useCase(senderId: 'a', receiverId: 'b', now: now);
      final second = await useCase(senderId: 'a', receiverId: 'b', now: now);
      final reverseDuplicate = await useCase(
        senderId: 'b',
        receiverId: 'a',
        now: now,
      );

      expect(
        (second as SendFriendRequestBlocked).reason,
        FriendActionFailureReason.duplicateRequest,
      );
      expect(
        (reverseDuplicate as SendFriendRequestBlocked).reason,
        FriendActionFailureReason.duplicateRequest,
      );
    });

    test('requesting someone already a friend is blocked', () async {
      final repository = InMemorySocialRepository();
      final sendUseCase = SendFriendRequestUseCase(repository);
      final acceptUseCase = AcceptFriendRequestUseCase(repository);

      final sent =
          await sendUseCase(senderId: 'a', receiverId: 'b', now: now)
              as SendFriendRequestSent;
      await acceptUseCase(sent.request.id, now: now);

      final result = await sendUseCase(
        senderId: 'a',
        receiverId: 'b',
        now: now,
      );
      expect(
        (result as SendFriendRequestBlocked).reason,
        FriendActionFailureReason.alreadyFriends,
      );
    });

    test(
      'a fresh request is allowed again after a prior one was rejected',
      () async {
        final repository = InMemorySocialRepository();
        final sendUseCase = SendFriendRequestUseCase(repository);
        final rejectUseCase = RejectFriendRequestUseCase(repository);

        final first =
            await sendUseCase(senderId: 'a', receiverId: 'b', now: now)
                as SendFriendRequestSent;
        await rejectUseCase(first.request.id);

        final result = await sendUseCase(
          senderId: 'a',
          receiverId: 'b',
          now: now,
        );
        expect(result, isA<SendFriendRequestSent>());
      },
    );
  });

  group('AcceptFriendRequestUseCase', () {
    test('accepting a pending request creates a friendship', () async {
      final repository = InMemorySocialRepository();
      final sendUseCase = SendFriendRequestUseCase(repository);
      final acceptUseCase = AcceptFriendRequestUseCase(repository);

      final sent =
          await sendUseCase(senderId: 'a', receiverId: 'b', now: now)
              as SendFriendRequestSent;
      final result = await acceptUseCase(sent.request.id, now: now);

      expect(result, isA<FriendRequestAccepted>());
      expect(await repository.areFriends('a', 'b'), isTrue);
    });

    test('accepting an unknown request id fails safely', () async {
      final repository = InMemorySocialRepository();
      final acceptUseCase = AcceptFriendRequestUseCase(repository);

      final result = await acceptUseCase('does-not-exist');
      expect(
        (result as RespondToFriendRequestFailed).reason,
        FriendActionFailureReason.requestNotFound,
      );
    });

    test('accepting an already-resolved request fails safely', () async {
      final repository = InMemorySocialRepository();
      final sendUseCase = SendFriendRequestUseCase(repository);
      final acceptUseCase = AcceptFriendRequestUseCase(repository);

      final sent =
          await sendUseCase(senderId: 'a', receiverId: 'b', now: now)
              as SendFriendRequestSent;
      await acceptUseCase(sent.request.id, now: now);
      final second = await acceptUseCase(sent.request.id, now: now);

      expect(
        (second as RespondToFriendRequestFailed).reason,
        FriendActionFailureReason.requestNotPending,
      );
    });
  });

  group('RejectFriendRequestUseCase', () {
    test(
      'rejecting a pending request marks it rejected, creates no friendship',
      () async {
        final repository = InMemorySocialRepository();
        final sendUseCase = SendFriendRequestUseCase(repository);
        final rejectUseCase = RejectFriendRequestUseCase(repository);

        final sent =
            await sendUseCase(senderId: 'a', receiverId: 'b', now: now)
                as SendFriendRequestSent;
        final result = await rejectUseCase(sent.request.id);

        expect(result, isA<FriendRequestRejected>());
        expect(await repository.areFriends('a', 'b'), isFalse);
      },
    );
  });

  group('RemoveFriendUseCase', () {
    test('removing an existing friendship succeeds', () async {
      final repository = InMemorySocialRepository();
      final sendUseCase = SendFriendRequestUseCase(repository);
      final acceptUseCase = AcceptFriendRequestUseCase(repository);
      final removeUseCase = RemoveFriendUseCase(repository);

      final sent =
          await sendUseCase(senderId: 'a', receiverId: 'b', now: now)
              as SendFriendRequestSent;
      await acceptUseCase(sent.request.id, now: now);

      final result = await removeUseCase('a', 'b');
      expect(result, isA<FriendRemoved>());
      expect(await repository.areFriends('a', 'b'), isFalse);
    });

    test('removing a non-friend fails safely', () async {
      final repository = InMemorySocialRepository();
      final removeUseCase = RemoveFriendUseCase(repository);

      final result = await removeUseCase('a', 'b');
      expect(
        (result as RemoveFriendFailed).reason,
        FriendActionFailureReason.notFriends,
      );
    });
  });

  test('no duplicate friendship rows are ever created, even if the '
      'repository is asked to create the same one twice', () async {
    final repository = InMemorySocialRepository();
    final sendUseCase = SendFriendRequestUseCase(repository);
    final acceptUseCase = AcceptFriendRequestUseCase(repository);

    final sent =
        await sendUseCase(senderId: 'a', receiverId: 'b', now: now)
            as SendFriendRequestSent;
    await acceptUseCase(sent.request.id, now: now);

    // Simulate a second, redundant creation attempt directly.
    await repository.createFriendship(
      Friendship(userId: 'a', friendId: 'b', createdAt: now),
    );

    final friendships = await repository.friendshipsFor('a');
    expect(friendships, hasLength(1));
  });
}
