import 'package:flutter/foundation.dart';

import '../enums/activity_event_type.dart';

/// One entry in the social activity feed. [headline] is a precomputed,
/// already-public-safe display string — the feed never re-derives text
/// from private data at render time, so there is never a code path where
/// a widget could accidentally interpolate something sensitive into it.
@immutable
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.type,
    required this.headline,
    required this.occurredAt,
  });

  final String id;
  final String userId;
  final String displayName;
  final ActivityEventType type;
  final String headline;
  final DateTime occurredAt;
}
