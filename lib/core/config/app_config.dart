/// Which backing services the app talks to.
///
/// `mock` (the default) runs entirely offline against in-memory/local data —
/// no Supabase project or AI provider credentials required. `live` talks to
/// a real Supabase project — which one is a separate, explicit axis, see
/// [SupabaseTarget].
enum AppEnvironment { mock, live }

/// Which real Supabase project `live` mode points at — orthogonal to
/// [AppEnvironment] on purpose: "are we live at all" and "which live
/// environment" are two different questions, and conflating them into one
/// enum is exactly how a build silently pointed at the wrong project. Only
/// meaningful when [AppConfig.isLive]; mock mode never reads this.
///
/// There is deliberately no default here. A `live` build with
/// `SUPABASE_TARGET` unset or unrecognized is treated as unconfigured
/// (see [AppConfig.supabaseTarget]) — it must be named explicitly, every
/// time, so `production` can never be what a build silently falls back to.
enum SupabaseTarget { staging, production }

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

  static const String _rawSupabaseTarget = String.fromEnvironment(
    'SUPABASE_TARGET',
  );

  /// `null` for mock mode, an unset `SUPABASE_TARGET`, or an unrecognized
  /// value — all three are "not explicitly named" and treated identically
  /// by [isSupabaseConfigured]/the safety guards. Never guesses; a typo'd
  /// value (`stagin`) fails exactly like an empty one, not like `staging`.
  static SupabaseTarget? get supabaseTarget => switch (_rawSupabaseTarget) {
    'staging' => SupabaseTarget.staging,
    'production' => SupabaseTarget.production,
    _ => null,
  };

  static bool get isStaging => supabaseTarget == SupabaseTarget.staging;
  static bool get isProduction => supabaseTarget == SupabaseTarget.production;

  /// Explicit, compile-time-only escape hatch for
  /// [assertAuthRepositoryConfigIsSafe]/[assertBackendModeConfigIsSafe]'s
  /// "refuse a release build wired to mock" rule. That rule exists to
  /// catch someone *forgetting* to configure live Supabase before a real
  /// production release — it was written before Roadmap Item 22 ("Free
  /// Public Beta Launch") introduced a release build that is
  /// *deliberately* mock-only and zero-cost. Rather than weakening the
  /// guard for every release build, this names the one case it should
  /// let through: a build that explicitly declares itself an authorized
  /// public beta via `--dart-define=CAN_PUBLIC_BETA=true` (set by
  /// `.github/workflows/android_beta_signed_build.yml`, not a secret —
  /// just a build-intent flag). Defaults to `false`, so a release build
  /// that omits this flag is refused exactly as before.
  static const bool isPublicBetaBuild = bool.fromEnvironment(
    'CAN_PUBLIC_BETA',
    defaultValue: false,
  );

  /// `SUPABASE_TARGET` is required, not just `SUPABASE_URL`/
  /// `SUPABASE_ANON_KEY` — a live build with credentials but no named
  /// target is exactly the "which environment is this actually pointed
  /// at" ambiguity this type exists to close off. See
  /// [assertBackendModeConfigIsSafe]/[assertAuthRepositoryConfigIsSafe]
  /// for where an unconfigured live build is refused outright.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      supabaseTarget != null;
}
