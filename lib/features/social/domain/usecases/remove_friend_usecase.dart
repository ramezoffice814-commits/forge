import 'package:flutter/foundation.dart';

import '../enums/friend_action_failure_reason.dart';
import '../repositories/social_repository.dart';

@immutable
sealed class RemoveFriendResult {
  const RemoveFriendResult();
}

class FriendRemoved extends RemoveFriendResult {
  const FriendRemoved();
}

class RemoveFriendFailed extends RemoveFriendResult {
  const RemoveFriendFailed(this.reason);
  final FriendActionFailureReason reason;
}

class RemoveFriendUseCase {
  const RemoveFriendUseCase(this._repository);

  final SocialRepository _repository;

  Future<RemoveFriendResult> call(String userId, String friendId) async {
    if (!await _repository.areFriends(userId, friendId)) {
      return const RemoveFriendFailed(FriendActionFailureReason.notFriends);
    }
    await _repository.removeFriendship(userId, friendId);
    return const FriendRemoved();
  }
}
