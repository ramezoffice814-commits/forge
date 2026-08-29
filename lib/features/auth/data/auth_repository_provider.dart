import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../../core/config/app_config.dart';
import '../../../core/storage/secure_key_value_store.dart';
import '../domain/auth_repository.dart';
import 'auth_repository_config_guard.dart';
import 'mock/mock_auth_repository.dart';
import 'supabase/supabase_auth_repository.dart';

/// Selects [MockAuthRepository] or [SupabaseAuthRepository] behind the
/// single [AuthRepository] interface, based on [AppConfig.environment].
/// `main.dart` only calls `Supabase.initialize` when live mode is
/// selected, so `Supabase.instance.client` is safe to read here whenever
/// that branch runs.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  assertAuthRepositoryConfigIsSafe(
    isRelease: kReleaseMode,
    isMock: AppConfig.isMock,
    isSupabaseConfigured: AppConfig.isSupabaseConfigured,
    isAuthorizedBetaBuild: AppConfig.isPublicBetaBuild,
  );

  if (AppConfig.isMock) {
    return MockAuthRepository(ref.watch(secureKeyValueStoreProvider));
  }
  return SupabaseAuthRepository(supa.Supabase.instance.client);
});
