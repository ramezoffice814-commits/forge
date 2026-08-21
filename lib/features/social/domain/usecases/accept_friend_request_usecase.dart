import '../entities/friendship.dart';
import '../enums/friend_action_failure_reason.dart';
import '../enums/friend_request_status.dart';
import '../repositories/social_repository.dart';
import 'respond_to_friend_request_result.dart';

class AcceptFriendRequestUseCase {
  const AcceptFriendRequestUseCase(this._repository);

  final SocialRepository _repository;

  Future<RespondToFriendRequestResult> call(
    String requestId, {
    DateTime? now,
  }) async {
    final request = await _repository.getRequestById(requestId);
    if (request == null) {
      return const RespondToFriendRequestFailed(
        FriendActionFailureReason.requestNotFound,
      );
    }
    if (request.status != FriendRequestStatus.pending) {
      return const RespondToFriendRequestFailed(
        FriendActionFailureReason.requestNotPending,
      );
    }

    await _repository.updateRequestStatus(
      requestId,
      FriendRequestStatus.accepted,
    );

    final friendship = Friendship(
      userId: request.senderId,
      friendId: request.receiverId,
      createdAt: now ?? DateTime.now(),
    );
    await _repository.createFriendship(friendship);

    return FriendRequestAccepted(friendship);
  }
}
