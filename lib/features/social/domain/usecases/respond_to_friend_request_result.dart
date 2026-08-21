import 'package:flutter/foundation.dart';

import '../entities/friendship.dart';
import '../enums/friend_action_failure_reason.dart';

/// Shared result hierarchy for `AcceptFriendRequestUseCase` and
/// `RejectFriendRequestUseCase` — both resolve one request, so both report
/// the same success/failure shape.
@immutable
sealed class RespondToFriendRequestResult {
  const RespondToFriendRequestResult();
}

class FriendRequestAccepted extends RespondToFriendRequestResult {
  const FriendRequestAccepted(this.friendship);
  final Friendship friendship;
}

class FriendRequestRejected extends RespondToFriendRequestResult {
  const FriendRequestRejected();
}

class RespondToFriendRequestFailed extends RespondToFriendRequestResult {
  const RespondToFriendRequestFailed(this.reason);
  final FriendActionFailureReason reason;
}
