/// Every "safe failure" a friend-system use case can report — never a
/// thrown exception for an expected, everyday case (a duplicate request,
/// a self-request, an already-resolved request). Exceptions stay reserved
/// for genuine programming errors.
enum FriendActionFailureReason {
  selfRequest,
  duplicateRequest,
  alreadyFriends,
  requestNotFound,
  requestNotPending,
  notFriends,
  profileNotVisible,
}

String friendActionFailureMessage(FriendActionFailureReason reason) {
  return switch (reason) {
    FriendActionFailureReason.selfRequest =>
      "You can't send a friend request to yourself.",
    FriendActionFailureReason.duplicateRequest =>
      'A friend request is already pending between these accounts.',
    FriendActionFailureReason.alreadyFriends => 'You are already friends.',
    FriendActionFailureReason.requestNotFound =>
      "That friend request doesn't exist.",
    FriendActionFailureReason.requestNotPending =>
      'That friend request has already been resolved.',
    FriendActionFailureReason.notFriends => 'You are not friends.',
    FriendActionFailureReason.profileNotVisible =>
      "This profile isn't visible to you.",
  };
}
