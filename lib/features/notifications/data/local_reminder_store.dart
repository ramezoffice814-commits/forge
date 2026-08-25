import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_key_value_store.dart';

/// Persists "when was this local reminder last shown" per dedup key —
/// the client-side half of Roadmap Item 15's dedup/cooldown story (the
/// server half is `forge_create_notification`'s own unique constraint).
/// Deliberately one key per dedup_key, not one big blob: keeps a lookup
/// to a single read, and a corrupt/missing entry for one reminder type
/// can never affect any other.
class LocalReminderStore {
  const LocalReminderStore(this._store);

  final SecureKeyValueStore _store;

  static String _key(String dedupKey) => 'forge.notifications.local_reminder.$dedupKey';

  Future<DateTime?> lastShownAt(String dedupKey) async {
    final raw = await _store.read(_key(dedupKey));
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> recordShown(String dedupKey, DateTime shownAt) {
    return _store.write(_key(dedupKey), shownAt.toIso8601String());
  }
}

final localReminderStoreProvider = Provider<LocalReminderStore>((ref) {
  return LocalReminderStore(ref.watch(secureKeyValueStoreProvider));
});
