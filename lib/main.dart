import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  }

  runApp(const ProviderScope(child: ForgeApp()));
}
