import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'app.dart';
import 'core/config/ai_coach_mode.dart';
import 'core/config/app_config.dart';
import 'core/error/crash_handler.dart';

Future<void> main() async {
  // Wraps startup and runApp so an uncaught async error anywhere (not
  // just inside Flutter's own build/layout/paint pipeline, which
  // installCrashHandlers()'s FlutterError.onError already covers) is
  // logged instead of silently terminating the app (Roadmap Item 18
  // section 7).
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    installCrashHandlers();

    // Mock mode (the default) never touches Supabase — no project or
    // credentials required to run the app. Live mode requires them; this
    // fails loudly rather than silently falling back to mock (see
    // assertAuthRepositoryConfigIsSafe for the matching repository-selection
    // guard).
    if (AppConfig.isLive) {
      if (!AppConfig.isSupabaseConfigured) {
        throw StateError(
          'APP_ENV=live but SUPABASE_URL/SUPABASE_ANON_KEY were not '
          'provided via --dart-define.',
        );
      }
      await supa.Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
    } else if (resolveAiCoachMode(
          aiCoachLiveFlag: AppConfig.aiCoachLiveFlag,
          isSupabaseConfigured: AppConfig.isSupabaseConfigured,
        ) ==
        AiCoachMode.live) {
      // AI Coach alone reaching a real Supabase project while the rest
      // of the backend stays mock (see ai_coach_mode.dart) — mutually
      // exclusive with the block above so Supabase.initialize() is
      // never called twice. Unlike the live-backend branch, no loud
      // failure here: resolveAiCoachMode already only returns `live`
      // when Supabase is actually configured, and going live is an
      // opt-in, low-stakes request for this feature specifically.
      await supa.Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );

      // AI Coach needs *some* real Supabase identity to call the
      // ai-coach Edge Function — auth is mandatory there, same as every
      // other Forge function — even though the rest of the app's own
      // sign-in stays mock. Anonymous auth is Supabase's own
      // purpose-built answer for exactly this: a real, RLS-respecting
      // identity with no user-facing sign-up step. Skipped if a session
      // already exists (Supabase.initialize restores any persisted one
      // automatically), so this never mints a fresh anonymous user on
      // every launch.
      if (supa.Supabase.instance.client.auth.currentSession == null) {
        try {
          await supa.Supabase.instance.client.auth.signInAnonymously();
        } catch (_) {
          // Anonymous sign-in disabled on the project, or a network
          // failure: AI Coach calls will fail closed (401 from the Edge
          // Function) and AiCoachRepository's own never-throws contract
          // degrades to the mock fallback template — never a crash here.
        }
      }
    }

    runApp(const ProviderScope(child: ForgeApp()));
  }, (error, stack) => logCrash(error, stack, source: 'zone'));
}
