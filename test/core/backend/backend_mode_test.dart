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
  });

  group('buildBackendModeStatus', () {
    test('never throws and reflects the given mode', () {
      final status = buildBackendModeStatus(BackendMode.mock);
      expect(status.mode, BackendMode.mock);
    });
  });
}
