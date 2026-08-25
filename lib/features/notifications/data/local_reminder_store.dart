import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_key_value_store.dart';

/// Persists "when was this local reminder last shown" per (user, dedup
/// key) — the client-side half of Roadmap Item 15's dedup/cooldown story
/// (the server half is `forge_create_notification`'s own unique
/// constraint). Deliberately one key per dedup_key, not one big blob:
/// keeps a lookup to a single read, and a corrupt/missing entry for one
/// reminder type can never affect any other.
///
/// Keyed by [userId] — same reasoning as `CachedMissionAssignmentStore`'s
/// own per-user key: the dedup keys themselves are date-based
/// (`daily_mission:2026-08-25`), not user-based, so without this a second
/// account signing in on the same device would inherit the first
/// account's "already shown today" state and silently lose a reminder
/// that was never actually shown to them (spec section 10: account
/// switching must not leak state between users).
class LocalReminderStore {
  const LocalReminderStore(this._store);

  final SecureKeyValueStore _store;

  static String _key(String userId, String dedupKey) =>
      'forge.notifications.local_reminder.$userId.$dedupKey';

  Future<DateTime?> lastShownAt(String userId, String dedupKey) async {
    final raw = await _store.read(_key(userId, dedupKey));
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> recordShown(String userId, String dedupKey, DateTime shownAt) {
    return _store.write(_key(userId, dedupKey), shownAt.toIso8601String());
  }
}

final localReminderStoreProvider = Provider<LocalReminderStore>((ref) {
  return LocalReminderStore(ref.watch(secureKeyValueStoreProvider));
});
