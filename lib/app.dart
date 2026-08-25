import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/forge_theme.dart';
import 'features/ai_coach/presentation/providers/ai_coach_providers.dart';

class ForgeApp extends ConsumerWidget {
  const ForgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Restores the user's saved AI privacy choice, if any (Roadmap Item
    // 14B) — fire-and-forget from the widget's perspective; every reader
    // of aiPrivacyLevelProvider stays synchronous and simply sees the
    // default until this resolves.
    ref.watch(aiPrivacyBootstrapProvider);
    return MaterialApp.router(
      title: 'Forge',
      debugShowCheckedModeBanner: false,
      theme: ForgeTheme.dark(),
      darkTheme: ForgeTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
