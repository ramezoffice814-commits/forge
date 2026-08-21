import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/auth_state_notifier.dart';
import '../../features/onboarding/presentation/onboarding_status.dart';
import '../../features/onboarding/presentation/onboarding_status_notifier.dart';
import 'app_routes.dart';

/// Router-facing contract for gating navigation on auth state. Keeps
/// auth business logic out of `core/router` entirely: the router only ever
/// calls [redirect] and acts on the result, it never knows *why*.
abstract class AuthRedirectPolicy {
  /// Returns a location to redirect to, or `null` to allow navigation.
  String? redirect(BuildContext context, GoRouterState state);
}

/// Always allows navigation — used in tests that want to exercise routing
/// or shell mechanics without dragging real auth/onboarding state through
/// them (override `authRedirectPolicyProvider` with this).
class NoAuthRedirectPolicy implements AuthRedirectPolicy {
  const NoAuthRedirectPolicy();

  @override
  String? redirect(BuildContext context, GoRouterState state) => null;
}

/// The real policy: every decision is derived from [authStateNotifierProvider]
/// and [onboardingStatusProvider] — never a widget-local boolean.
///
/// Rules:
/// - Still restoring the session or loading the onboarding flag → stay on
///   (or go to) splash.
/// - Authenticated user on splash/onboarding/sign-in/sign-up/forgot-password
///   → home (or a preserved `redirect` target, see below).
/// - Unauthenticated user opening a protected route → sign-in, with
///   `?redirect=<path>` so sign-in can send them back afterward.
/// - Unauthenticated user on splash → onboarding if they haven't completed
///   it yet, otherwise sign-in.
/// - Anything else (already on onboarding/sign-in/sign-up/forgot-password
///   while unauthenticated) is left alone — no forced detours, no loops.
class AuthStateAwareRedirectPolicy implements AuthRedirectPolicy {
  AuthStateAwareRedirectPolicy(this._ref);

  final Ref _ref;

  @override
  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authStateNotifierProvider);
    final onboarding = _ref.read(onboardingStatusProvider);
    final location = state.matchedLocation;

    final stillLoading =
        auth.status == AuthStatus.initial ||
        auth.status == AuthStatus.restoring ||
        onboarding is OnboardingStatusLoading;

    if (stillLoading) {
      return location == AppRoutePaths.splash ? null : AppRoutePaths.splash;
    }

    final isSplash = location == AppRoutePaths.splash;
    final isOnboarding = location == AppRoutePaths.onboarding;
    final isPublicAuthRoute = AppRoutePaths.publicAuthRoutes.contains(location);
    final isProtected =
        AppRoutePaths.protected.contains(location) ||
        location.startsWith(AppRoutePaths.activeMissionPrefix) ||
        location.startsWith(AppRoutePaths.publicProfilePrefix);
    final authenticated = auth.status == AuthStatus.authenticated;

    if (authenticated) {
      if (isSplash || isOnboarding || isPublicAuthRoute) {
        final redirectTo = state.uri.queryParameters['redirect'];
        if (redirectTo != null &&
            (AppRoutePaths.protected.contains(redirectTo) ||
                redirectTo.startsWith(AppRoutePaths.activeMissionPrefix) ||
                redirectTo.startsWith(AppRoutePaths.publicProfilePrefix))) {
          return redirectTo;
        }
        return AppRoutePaths.home;
      }
      return null;
    }

    if (isProtected) {
      return Uri(
        path: AppRoutePaths.signIn,
        queryParameters: {'redirect': location},
      ).toString();
    }

    if (isSplash) {
      final onboardingDone =
          onboarding is OnboardingStatusLoaded && onboarding.completed;
      return onboardingDone ? AppRoutePaths.signIn : AppRoutePaths.onboarding;
    }

    return null;
  }
}

final authRedirectPolicyProvider = Provider<AuthRedirectPolicy>((ref) {
  return AuthStateAwareRedirectPolicy(ref);
});
