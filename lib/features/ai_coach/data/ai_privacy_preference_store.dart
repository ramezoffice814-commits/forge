import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_key_value_store.dart';
import '../domain/enums/ai_privacy_level.dart';

/// Persists the user's AI privacy choice (Roadmap Item 14B) using the
/// same existing local storage abstraction other Forge preferences use
/// (mirrors `LocalOnboardingRepository`'s exact shape) — no new storage
/// subsystem. Deliberately narrow: this class stores and retrieves one
/// enum value, nothing else.
///
/// Keyed by [userId] — found during Roadmap Item 16's account-switch
/// audit: the original single, non-user-scoped key meant a second
/// account signing in on the same device would silently inherit the
/// first account's AI privacy choice (or overwrite it on save), exactly
/// the class of bug already found and fixed for `LocalReminderStore` in
/// Item 15. Matches `CachedMissionAssignmentStore`'s existing per-user
/// key convention.
class AiPrivacyPreferenceStore {
  const AiPrivacyPreferenceStore(this._store);

  final SecureKeyValueStore _store;

  static String _key(String userId) => 'forge.ai_coach.privacy_level.$userId';

  /// `null` when nothing has been saved yet for this user — callers
  /// should keep whatever default they already have (currently
  /// [AiPrivacyLevel.limitedContext]) rather than treating this as
  /// [AiPrivacyLevel.disabled] or any other specific value.
  Future<AiPrivacyLevel?> load(String userId) async {
    final raw = await _store.read(_key(userId));
    if (raw == null) return null;
    for (final level in AiPrivacyLevel.values) {
      if (level.name == raw) return level;
    }
    return null;
  }

  Future<void> save(String userId, AiPrivacyLevel level) =>
      _store.write(_key(userId), level.name);
}

final aiPrivacyPreferenceStoreProvider = Provider<AiPrivacyPreferenceStore>((
  ref,
) {
  return AiPrivacyPreferenceStore(ref.watch(secureKeyValueStoreProvider));
});
