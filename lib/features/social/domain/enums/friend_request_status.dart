/// A friend request's lifecycle — closed set so every use case can
/// exhaustively switch over it rather than checking a raw string/bool.
enum FriendRequestStatus { pending, accepted, rejected }
