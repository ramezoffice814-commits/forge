import 'package:flutter/foundation.dart';

import '../entities/friend_request.dart';
import '../enums/friend_action_failure_reason.dart';
import '../enums/friend_request_status.dart';
import '../repositories/social_repository.dart';

@immutable
sealed class SendFriendRequestResult {
  const SendFriendRequestResult();
}

class SendFriendRequestSent extends SendFriendRequestResult {
  const SendFriendRequestSent(this.request);
  final FriendRequest request;
}

class SendFriendRequestBlocked extends SendFriendRequestResult {
  const SendFriendRequestBlocked(this.reason);
  final FriendActionFailureReason reason;
}

/// Rules enforced here, never left to the UI: no self-requests, no
/// duplicate pending requests, no requesting someone already a friend.
/// Every rejection is a returned value, not a thrown exception — these are
/// everyday, expected outcomes.
class SendFriendRequestUseCase {
  const SendFriendRequestUseCase(this._repository);

  final SocialRepository _repository;

  Future<SendFriendRequestResult> call({
    required String senderId,
    required String receiverId,
    DateTime? now,
  }) async {
    if (senderId == receiverId) {
      return const SendFriendRequestBlocked(
        FriendActionFailureReason.selfRequest,
      );
    }

    if (await _repository.areFriends(senderId, receiverId)) {
      return const SendFriendRequestBlocked(
        FriendActionFailureReason.alreadyFriends,
      );
    }

    final existing = await _repository.existingRequestBetween(
      senderId,
      receiverId,
    );
    if (existing != null && existing.status == FriendRequestStatus.pending) {
      return const SendFriendRequestBlocked(
        FriendActionFailureReason.duplicateRequest,
      );
    }

    final effectiveNow = now ?? DateTime.now();
    final request = FriendRequest(
      id: '$senderId-$receiverId-${effectiveNow.microsecondsSinceEpoch}',
      senderId: senderId,
      receiverId: receiverId,
      status: FriendRequestStatus.pending,
      createdAt: effectiveNow,
    );

    final created = await _repository.createRequest(request);
    return SendFriendRequestSent(created);
  }
}
