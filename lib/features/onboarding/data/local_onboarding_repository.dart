import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_key_value_store.dart';
import '../domain/onboarding_repository.dart';

class LocalOnboardingRepository implements OnboardingRepository {
  const LocalOnboardingRepository(this._store);

  static const _key = 'forge.onboarding.completed';

  final SecureKeyValueStore _store;

  @override
  Future<bool> isCompleted() async {
    final raw = await _store.read(_key);
    return raw == 'true';
  }

  @override
  Future<void> markCompleted() => _store.write(_key, 'true');
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return LocalOnboardingRepository(ref.watch(secureKeyValueStoreProvider));
});
