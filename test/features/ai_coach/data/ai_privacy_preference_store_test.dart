import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/ai_coach/data/ai_privacy_preference_store.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_privacy_level.dart';

import '../../../support/fake_secure_key_value_store.dart';

void main() {
  test('load() returns null when nothing has been saved yet', () async {
    final store = AiPrivacyPreferenceStore(FakeSecureKeyValueStore());
    expect(await store.load('user-a'), isNull);
  });

  test('save() then load() round-trips every privacy level', () async {
    final store = AiPrivacyPreferenceStore(FakeSecureKeyValueStore());
    for (final level in AiPrivacyLevel.values) {
      await store.save('user-a', level);
      expect(await store.load('user-a'), level);
    }
  });

  test(
    'a fresh store instance backed by the same underlying storage still '
    'sees the saved value — the restart-restores-preference contract',
    () async {
      final backingStore = FakeSecureKeyValueStore();
      await AiPrivacyPreferenceStore(
        backingStore,
      ).save('user-a', AiPrivacyLevel.fullContext);

      // A brand-new AiPrivacyPreferenceStore instance, exactly as would
      // exist after an app restart creates a fresh provider graph.
      final restarted = AiPrivacyPreferenceStore(backingStore);
      expect(await restarted.load('user-a'), AiPrivacyLevel.fullContext);
    },
  );

  test(
    'load() returns null for a corrupt/unrecognized stored value, never throws',
    () async {
      final backingStore = FakeSecureKeyValueStore();
      await backingStore.write(
        'forge.ai_coach.privacy_level.user-a',
        'not_a_real_level',
      );
      final store = AiPrivacyPreferenceStore(backingStore);
      expect(await store.load('user-a'), isNull);
    },
  );

  test('two different users never share an AI privacy choice, even on the '
      'same device — a second account signing in must not inherit the '
      'first account\'s choice, and saving as one user must not overwrite '
      'the other\'s', () async {
    final backingStore = FakeSecureKeyValueStore();
    final store = AiPrivacyPreferenceStore(backingStore);

    await store.save('user-a', AiPrivacyLevel.fullContext);

    expect(await store.load('user-a'), AiPrivacyLevel.fullContext);
    expect(await store.load('user-b'), isNull);

    await store.save('user-b', AiPrivacyLevel.disabled);

    expect(await store.load('user-a'), AiPrivacyLevel.fullContext);
    expect(await store.load('user-b'), AiPrivacyLevel.disabled);
  });
}
