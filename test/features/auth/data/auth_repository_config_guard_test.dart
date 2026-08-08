import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/auth/data/auth_repository_config_guard.dart';

void main() {
  test('throws when a release build would run with mock auth', () {
    expect(
      () => assertAuthRepositoryConfigIsSafe(
        isRelease: true,
        isMock: true,
        isSupabaseConfigured: false,
      ),
      throwsA(isA<UnsafeAuthConfigException>()),
    );
  });

  test('throws when live mode is selected but Supabase is unconfigured', () {
    expect(
      () => assertAuthRepositoryConfigIsSafe(
        isRelease: false,
        isMock: false,
        isSupabaseConfigured: false,
      ),
      throwsA(isA<UnsafeAuthConfigException>()),
    );
  });

  test('allows a debug build with mock auth', () {
    expect(
      () => assertAuthRepositoryConfigIsSafe(
        isRelease: false,
        isMock: true,
        isSupabaseConfigured: false,
      ),
      returnsNormally,
    );
  });

  test('allows a release build with live mode and Supabase configured', () {
    expect(
      () => assertAuthRepositoryConfigIsSafe(
        isRelease: true,
        isMock: false,
        isSupabaseConfigured: true,
      ),
      returnsNormally,
    );
  });
}
