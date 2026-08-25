import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_key_value_store.dart';
import '../domain/enums/ai_privacy_level.dart';

/// Persists the user's AI privacy choice (Roadmap Item 14B) using the
/// same existing local storage abstraction other Forge preferences use
/// (mirrors `LocalOnboardingRepository`'s exact shape) — no new storage
/// subsystem. Deliberately narrow: this class stores and retrieves one
/// enum value, nothing else.
class AiPrivacyPreferenceStore {
  const AiPrivacyPreferenceStore(this._store);

  static const _key = 'forge.ai_coach.privacy_level';

  final SecureKeyValueStore _store;

  /// `null` when nothing has been saved yet — callers should keep
  /// whatever default they already have (currently
  /// [AiPrivacyLevel.limitedContext]) rather than treating this as
  /// [AiPrivacyLevel.disabled] or any other specific value.
  Future<AiPrivacyLevel?> load() async {
    final raw = await _store.read(_key);
    if (raw == null) return null;
    for (final level in AiPrivacyLevel.values) {
      if (level.name == raw) return level;
    }
    return null;
  }

  Future<void> save(AiPrivacyLevel level) => _store.write(_key, level.name);
}

final aiPrivacyPreferenceStoreProvider = Provider<AiPrivacyPreferenceStore>((
  ref,
) {
  return AiPrivacyPreferenceStore(ref.watch(secureKeyValueStoreProvider));
});
