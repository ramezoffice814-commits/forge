import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/backend/backend_mode.dart';

void main() {
  group('resolveBackendMode / assertBackendModeConfigIsSafe', () {
    test('development may run mock safely', () {
      final mode = resolveBackendMode(
        isRelease: false,
        isMock: true,
        isSupabaseConfigured: false,
      );
      expect(mode, BackendMode.mock);
    });

    test(
      'live mode with valid Supabase configuration resolves to liveSupabase',
      () {
        final mode = resolveBackendMode(
          isRelease: false,
          isMock: false,
          isSupabaseConfigured: true,
        );
        expect(mode, BackendMode.liveSupabase);
      },
    );

    test('release build against mock backend fails safely', () {
      expect(
        () => resolveBackendMode(
          isRelease: true,
          isMock: true,
          isSupabaseConfigured: false,
        ),
        throwsA(isA<UnsafeBackendModeException>()),
      );
    });

    test(
      'live mode without Supabase configured never silently falls back to mock',
      () {
        expect(
          () => resolveBackendMode(
            isRelease: false,
            isMock: false,
            isSupabaseConfigured: false,
          ),
          throwsA(isA<UnsafeBackendModeException>()),
        );
      },
    );

    test('release + live + configured is safe', () {
      final mode = resolveBackendMode(
        isRelease: true,
        isMock: false,
        isSupabaseConfigured: true,
      );
      expect(mode, BackendMode.liveSupabase);
    });

    // Regression coverage for the real-device startup-routing incident
    // (docs/ANDROID_BETA_DEVICE_TEST.md) — mirrors
    // auth_repository_config_guard_test.dart's coverage of the identical
    // guard shape in backend mode selection.
    test('an authorized public beta build may run a release build against '
        'the mock backend', () {
      final mode = resolveBackendMode(
        isRelease: true,
        isMock: true,
        isSupabaseConfigured: false,
        isAuthorizedBetaBuild: true,
      );
      expect(mode, BackendMode.mock);
    });

    test('an unauthorized release build against the mock backend is still '
        'refused when isAuthorizedBetaBuild is not explicitly passed', () {
      expect(
        () => resolveBackendMode(
          isRelease: true,
          isMock: true,
          isSupabaseConfigured: false,
        ),
        throwsA(isA<UnsafeBackendModeException>()),
      );
    });

    test(
      'isAuthorizedBetaBuild does not bypass the live-misconfiguration check',
      () {
        expect(
          () => resolveBackendMode(
            isRelease: false,
            isMock: false,
            isSupabaseConfigured: false,
            isAuthorizedBetaBuild: true,
          ),
          throwsA(isA<UnsafeBackendModeException>()),
        );
      },
    );
  });

  group('buildBackendModeStatus', () {
    test('never throws and reflects the given mode', () {
      final status = buildBackendModeStatus(BackendMode.mock);
      expect(status.mode, BackendMode.mock);
    });
  });
}
