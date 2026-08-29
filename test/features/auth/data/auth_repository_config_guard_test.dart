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

  // Regression coverage for the real-device startup-routing incident
  // (docs/ANDROID_BETA_DEVICE_TEST.md): the first signed beta APK
  // crashed on launch because this guard refused release+mock
  // unconditionally, with no way for an intentional public beta build
  // to declare itself authorized.
  test(
    'an authorized public beta build may run a release build with mock auth',
    () {
      expect(
        () => assertAuthRepositoryConfigIsSafe(
          isRelease: true,
          isMock: true,
          isSupabaseConfigured: false,
          isAuthorizedBetaBuild: true,
        ),
        returnsNormally,
      );
    },
  );

  test('an unauthorized release build with mock auth is still refused even '
      'when isAuthorizedBetaBuild is not explicitly passed', () {
    expect(
      () => assertAuthRepositoryConfigIsSafe(
        isRelease: true,
        isMock: true,
        isSupabaseConfigured: false,
      ),
      throwsA(isA<UnsafeAuthConfigException>()),
    );
  });

  test(
    'isAuthorizedBetaBuild does not bypass the live-misconfiguration check',
    () {
      expect(
        () => assertAuthRepositoryConfigIsSafe(
          isRelease: false,
          isMock: false,
          isSupabaseConfigured: false,
          isAuthorizedBetaBuild: true,
        ),
        throwsA(isA<UnsafeAuthConfigException>()),
      );
    },
  );
}
