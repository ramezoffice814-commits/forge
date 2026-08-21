import 'package:flutter/foundation.dart';

/// One accepted friendship — created only by
/// `AcceptFriendRequestUseCase`, never constructed directly elsewhere.
/// [userId]/[friendId] are an unordered pair in practice (repositories
/// must check both directions when looking up a user's friends), kept as
/// two plain fields rather than a `Set` so the record stays simple to
/// store and query.
@immutable
class Friendship {
  const Friendship({
    required this.userId,
    required this.friendId,
    required this.createdAt,
  });

  final String userId;
  final String friendId;
  final DateTime createdAt;

  bool involves(String candidateId) =>
      userId == candidateId || friendId == candidateId;

  /// The other participant, given one side of the pair.
  String otherUserId(String knownUserId) {
    if (knownUserId == userId) return friendId;
    if (knownUserId == friendId) return userId;
    throw ArgumentError('$knownUserId is not part of this friendship');
  }
}
