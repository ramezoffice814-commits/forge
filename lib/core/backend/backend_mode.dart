import '../config/app_config.dart';

/// Which [BackendClient] implementation the app actually talks to —
/// derived from [AppConfig], never a separate `--dart-define`, so there
/// is exactly one source of truth for "mock vs. live" across auth and
/// backend selection.
enum BackendMode { mock, liveSupabase }

/// Thrown by [assertBackendModeConfigIsSafe] — an unsafe configuration
/// that must never be allowed to run, mirroring
/// `assertAuthRepositoryConfigIsSafe`'s exact shape (see
/// `lib/features/auth/data/auth_repository_config_guard.dart`) so the two
/// guards read identically and can never quietly drift apart.
class UnsafeBackendModeException implements Exception {
  const UnsafeBackendModeException(this.message);

  final String message;

  @override
  String toString() => 'UnsafeBackendModeException: $message';
}

/// Guards against the same two ways backend mode selection could go
/// quietly wrong as auth does: shipping a release build wired to the
/// mock backend, or silently falling back to mock when live mode was
/// requested but Supabase isn't configured. Pure and synchronous — no
/// `kReleaseMode`/`AppConfig` reads inside — so it's testable with
/// synthetic inputs.
///
/// [isAuthorizedBetaBuild] mirrors
/// `assertAuthRepositoryConfigIsSafe`'s own parameter of the same name
/// (see `lib/features/auth/data/auth_repository_config_guard.dart` and
/// `AppConfig.isPublicBetaBuild`) — the two guards must never drift
/// apart on which release+mock combination is actually authorized.
void assertBackendModeConfigIsSafe({
  required bool isRelease,
  required bool isMock,
  required bool isSupabaseConfigured,
  bool isAuthorizedBetaBuild = false,
}) {
  if (isRelease && isMock && !isAuthorizedBetaBuild) {
    throw const UnsafeBackendModeException(
      'Refusing to run a release build against the mock backend. Build '
      'with --dart-define=APP_ENV=live and Supabase credentials, or '
      '--dart-define=CAN_PUBLIC_BETA=true for an authorized beta build.',
    );
  }
  if (!isMock && !isSupabaseConfigured) {
    throw const UnsafeBackendModeException(
      'APP_ENV=live but SUPABASE_URL/SUPABASE_ANON_KEY are missing — '
      'refusing to silently fall back to the mock backend.',
    );
  }
}

/// Resolves [AppConfig] into the one [BackendMode] the app runs against.
/// Never returns [BackendMode.liveSupabase] unless Supabase is actually
/// configured — there is no third "degraded" mode returned here; a
/// backend that becomes unreachable *after* this resolves is a runtime
/// connectivity concern for [SyncQueueingBackendClient], not a mode
/// change (see spec section 8: "enter degraded/offline state cleanly",
/// which is a status, not a different [BackendMode]).
BackendMode resolveBackendMode({
  required bool isRelease,
  required bool isMock,
  required bool isSupabaseConfigured,
  bool isAuthorizedBetaBuild = false,
}) {
  assertBackendModeConfigIsSafe(
    isRelease: isRelease,
    isMock: isMock,
    isSupabaseConfigured: isSupabaseConfigured,
    isAuthorizedBetaBuild: isAuthorizedBetaBuild,
  );
  return isMock ? BackendMode.mock : BackendMode.liveSupabase;
}

/// A plain diagnostics snapshot — safe to log or show on a debug screen.
/// Never carries a credential value, only whether one is present.
class BackendModeStatus {
  const BackendModeStatus({
    required this.mode,
    required this.isSupabaseConfigured,
    required this.supabaseUrlHost,
    required this.supabaseTarget,
  });

  final BackendMode mode;
  final bool isSupabaseConfigured;

  /// Just the host portion of the configured Supabase URL (or `null`) —
  /// enough to confirm "which project" in a diagnostics view without
  /// ever surfacing the anon key itself.
  final String? supabaseUrlHost;

  /// `staging`/`production`/`null` — safe to show/log on its own; it is a
  /// label, never a credential. Lets a diagnostics screen or crash report
  /// say "this is staging" without ever needing the host or key nearby.
  final SupabaseTarget? supabaseTarget;

  @override
  String toString() =>
      'BackendModeStatus(mode: $mode, supabaseConfigured: '
      '$isSupabaseConfigured, host: $supabaseUrlHost, '
      'target: $supabaseTarget)';
}

BackendModeStatus buildBackendModeStatus(BackendMode mode) {
  String? host;
  if (AppConfig.isSupabaseConfigured) {
    host = Uri.tryParse(AppConfig.supabaseUrl)?.host;
  }
  return BackendModeStatus(
    mode: mode,
    isSupabaseConfigured: AppConfig.isSupabaseConfigured,
    supabaseUrlHost: host,
    supabaseTarget: AppConfig.supabaseTarget,
  );
}
