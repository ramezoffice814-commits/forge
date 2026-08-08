/// Which backing services the app talks to.
///
/// `mock` (the default) runs entirely offline against in-memory/local data —
/// no Supabase project or AI provider credentials required. `live` is wired
/// up as later features (auth, missions, AI) land; nothing reads it yet.
enum AppEnvironment { mock, live }

/// Compile-time app configuration, read via `--dart-define`.
///
/// Deliberately plain `String.fromEnvironment` rather than a generated
/// secrets package (e.g. `envied`) — the Supabase anon key is designed to
/// be public (access is enforced by Row Level Security, not by keeping the
/// key hidden), and there's no service-role key or other real secret here
/// to protect. Reach for `envied` if one is ever added — it must never go
/// through `String.fromEnvironment`/source control.
abstract final class AppConfig {
  static const String _rawEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'mock',
  );

  static const AppEnvironment environment = _rawEnvironment == 'live'
      ? AppEnvironment.live
      : AppEnvironment.mock;

  static bool get isMock => environment == AppEnvironment.mock;
  static bool get isLive => environment == AppEnvironment.live;

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
