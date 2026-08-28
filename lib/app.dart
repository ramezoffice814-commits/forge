import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/opening/can_opening_overlay.dart';
import 'core/router/app_router.dart';
import 'core/theme/forge_theme.dart';
import 'features/ai_coach/presentation/providers/ai_coach_providers.dart';
import 'features/notifications/presentation/providers/notification_providers.dart';

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
    // Initializes the OS notification plugin (if this platform supports
    // one — Roadmap Item 17) and wires notification taps to real
    // navigation. Also fire-and-forget: nothing here blocks the first
    // frame, and initialize() never throws even when unsupported.
    ref.watch(osNotificationBootstrapProvider);
    return MaterialApp.router(
      title: 'CAN',
      debugShowCheckedModeBanner: false,
      theme: ForgeTheme.dark(),
      darkTheme: ForgeTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      // Roadmap Item 21: the cinematic CAN opening lives here, not as a
      // route — it wraps whatever GoRouter has already resolved rather
      // than gating navigation on animation completion. See
      // CanOpeningOverlay's own doc comment for the full reasoning.
      builder: (context, child) =>
          CanOpeningOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
