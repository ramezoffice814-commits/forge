import 'package:forge/core/storage/secure_key_value_store.dart';

/// In-memory stand-in for [SecureKeyValueStore] — `flutter_secure_storage`'s
/// real implementation goes through a platform channel that isn't
/// available under plain `flutter test`, so anything exercising the real
/// [MockAuthRepository]/[LocalOnboardingRepository] needs this override.
class FakeSecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}
