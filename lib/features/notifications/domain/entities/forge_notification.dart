import 'package:flutter/foundation.dart';

import '../enums/forge_notification_type.dart';
import '../enums/notification_priority.dart';

/// One inbox entry — either a row synced from the server-authoritative
/// `notifications` table, or a locally-computed reminder
/// (`type.isServerAuthoritative == false`) that never touches the
/// server at all. Both shapes share this one type so the inbox UI has a
/// single, uniform model to render (spec section 5: "do not pass
/// arbitrary string blobs throughout the app").
@immutable
class ForgeNotification {
  const ForgeNotification({
    required this.id,
    required this.type,
    required this.dedupKey,
    required this.createdAt,
    required this.readAt,
    required this.metadata,
    this.priority = NotificationPriority.normal,
  });

  /// Server rows: the `notifications.id` UUID. Local reminders: a
  /// stable id derived from [dedupKey] (see
  /// `LocalReminderEngine`) — either way, unique enough for a
  /// `ValueKey`/dedup check, never used as a trust boundary itself.
  final String id;

  final ForgeNotificationType type;

  /// Mirrors the server's own dedup key shape for server rows
  /// (`achievement:<user>:<id>` etc.) and a locally-constructed
  /// equivalent for client-owned types (see
  /// `LocalReminderEngine.dedupKeyFor`) — the single source of truth
  /// this notification is "the same event" as any other with an equal
  /// key.
  final String dedupKey;

  final DateTime createdAt;

  /// `null` = unread. Local reminders track this via
  /// `LocalReminderStore`, mirroring the server column's own semantics
  /// exactly rather than inventing a second "seen" concept.
  final DateTime? readAt;

  /// Already-sanitized, non-sensitive fields only (spec section 5: "do
  /// not put secrets or unnecessary sensitive data into notification
  /// payloads") — display copy is derived from these via
  /// `NotificationCopy`, never stored pre-rendered, so it always stays
  /// consistent with whatever catalog (levels/achievements) the rest of
  /// the app already uses.
  final Map<String, Object?> metadata;

  final NotificationPriority priority;

  bool get isRead => readAt != null;

  ForgeNotification copyWith({DateTime? readAt}) {
    return ForgeNotification(
      id: id,
      type: type,
      dedupKey: dedupKey,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      metadata: metadata,
      priority: priority,
    );
  }
}
