import 'package:flutter/foundation.dart';

import '../enums/friend_request_status.dart';

@immutable
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final FriendRequestStatus status;
  final DateTime createdAt;

  FriendRequest copyWith({FriendRequestStatus? status}) {
    return FriendRequest(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
