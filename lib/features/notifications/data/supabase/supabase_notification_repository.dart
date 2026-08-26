import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../domain/entities/forge_notification.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_repository.dart';
import 'notification_row_mapper.dart';

/// Real, live-mode implementation. Every notification row this reads
/// was created exclusively by `forge_create_notification()` inside a
/// server transaction (see the Item 15 migration) — this class never
/// writes a new notification, only reads and marks-read, matching the
/// RLS grant it actually has (SELECT unrestricted, UPDATE narrowed to
/// `read_at` at the column-privilege level).
class SupabaseNotificationRepository implements NotificationRepository {
  const SupabaseNotificationRepository(this._client);

  /// `notifications` has no retention/archival policy (Roadmap Item 18
  /// production-readiness audit — see docs/RELEASE_READINESS.md) and
  /// this query runs on every inbox load, so it's bounded rather than
  /// pulling a long-lived, active user's entire unbounded history every
  /// time. 200 rows is generous for what's actually shown (recent
  /// achievement/level-up/week/season/weekly-recap rows) — a real
  /// retention/archival migration is a separate, larger piece of work,
  /// not something to invent here.
  static const _fetchLimit = 200;

  final supa.SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<ForgeNotification>> fetchInbox() async {
    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(_fetchLimit);

    return rows
        .map((row) => parseNotificationRow(row))
        .whereType<ForgeNotification>()
        .toList(growable: false);
  }

  @override
  Future<void> markRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId)
        .eq('user_id', _userId);
  }

  @override
  Future<void> markAllRead() async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', _userId)
        .isFilter('read_at', null);
  }

  @override
  Future<NotificationPreferences> getPreferences() async {
    final row = await _client
        .from('notification_preferences')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    // Bootstrapped by a trigger on signup (see the migration) — a
    // missing row should never happen for a real authenticated user,
    // but falls back to defaults rather than throwing if it somehow
    // does, since preferences are advisory, never load-bearing.
    if (row == null) return const NotificationPreferences();
    return parsePreferencesRow(row);
  }

  @override
  Future<void> updatePreferences(NotificationPreferences preferences) async {
    await _client
        .from('notification_preferences')
        .update(preferencesToRow(preferences))
        .eq('user_id', _userId);
  }
}
