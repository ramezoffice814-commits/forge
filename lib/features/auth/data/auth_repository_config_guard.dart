/// Thrown by [assertAuthRepositoryConfigIsSafe] — a configuration that
/// must never be allowed to run, not a recoverable auth failure.
class UnsafeAuthConfigException implements Exception {
  const UnsafeAuthConfigException(this.message);

  final String message;

  @override
  String toString() => 'UnsafeAuthConfigException: $message';
}

/// Guards against the two ways auth repository selection could go quietly
/// wrong: shipping a release build wired to [MockAuthRepository], or
/// silently falling back to mock when live mode is selected but Supabase
/// credentials are missing. Pure and synchronous on purpose — no
/// `kReleaseMode`/`AppConfig` reads inside, so it's exercisable with
/// synthetic inputs in tests rather than only via a real release build.
void assertAuthRepositoryConfigIsSafe({
  required bool isRelease,
  required bool isMock,
  required bool isSupabaseConfigured,
}) {
  if (isRelease && isMock) {
    throw const UnsafeAuthConfigException(
      'Refusing to run a release build with mock auth. Build with '
      '--dart-define=APP_ENV=live and Supabase credentials.',
    );
  }
  if (!isMock && !isSupabaseConfigured) {
    throw const UnsafeAuthConfigException(
      'APP_ENV=live but SUPABASE_URL/SUPABASE_ANON_KEY are missing — '
      'refusing to silently fall back to mock auth.',
    );
  }
}
