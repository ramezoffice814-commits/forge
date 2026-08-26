import 'package:flutter/foundation.dart';

/// Central place any uncaught error in this app passes through
/// (Roadmap Item 18 section 7). Before this, Forge had no explicit
/// `FlutterError.onError`/`PlatformDispatcher.onError` wiring at all —
/// an error outside Flutter's own build/layout/paint pipeline (a
/// platform-channel callback, a `Future` with no `catchError`) could
/// terminate the app with nothing logged anywhere.
///
/// Deliberately minimal: logs to the console (`debugPrint`, visible in
/// `flutter run`/CI output and any platform log collector already
/// watching stdout) and never wires a paid crash-reporting SaaS
/// (Crashlytics/Sentry) — that's a deliberate future decision (see
/// `docs/RELEASE_READINESS.md`), not something to add unprompted.
/// [logCrash] is the one seam a real crash reporter would hook into
/// later without touching either handler below.
void installCrashHandlers() {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    logCrash(
      details.exception,
      details.stack ?? StackTrace.empty,
      source: 'flutter',
    );
    // Preserves whatever Flutter would otherwise have done (console
    // dump, plus the on-screen error overlay in debug/profile builds)
    // — this handler adds logging, it doesn't replace the framework's
    // own presentation.
    (previousOnError ?? FlutterError.presentError)(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    logCrash(error, stack, source: 'platform');
    // Returning true marks this handled — the app stays alive instead
    // of the engine terminating the process, matching Flutter's own
    // documented recommendation for this hook.
    return true;
  };
}

/// Logs are developer-facing (console/CI output, or a future crash
/// reporter), not shown to users anywhere — so unlike a user-facing
/// error message, the real exception detail belongs here, not a
/// sanitized placeholder. Still never route this through any UI text.
void logCrash(Object error, StackTrace stack, {required String source}) {
  debugPrint('[forge:crash] source=$source error=$error');
  debugPrint(stack.toString());
}
