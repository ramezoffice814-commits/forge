import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal secure key-value persistence, backed by the platform keystore
/// (Keychain/Keystore/Credential Manager) via `flutter_secure_storage`.
/// Used for anything that shouldn't sit in plain local storage — the
/// persisted auth session, the onboarding-completion flag.
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final secureKeyValueStoreProvider = Provider<SecureKeyValueStore>((ref) {
  return const FlutterSecureKeyValueStore();
});
