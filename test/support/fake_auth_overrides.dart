import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge/features/auth/domain/entities/auth_session.dart';
import 'package:forge/features/auth/domain/entities/auth_user.dart';
import 'package:forge/features/auth/presentation/auth_state.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/onboarding/presentation/onboarding_status.dart';
import 'package:forge/features/onboarding/presentation/onboarding_status_notifier.dart';

/// A stand-in signed-in user for tests that aren't about auth itself.
final testAuthSession = AuthSession(
  user: AuthUser(
    id: 'test-user',
    displayName: 'Test User',
    email: 'test@forge.app',
    createdAt: DateTime.utc(2026, 1, 1),
    onboardingCompleted: true,
  ),
  accessToken: 'test-token',
);

class FakeAuthenticatedNotifier extends AuthStateNotifier {
  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      session: testAuthSession,
    );
  }
}

class FakeCompletedOnboardingNotifier extends OnboardingStatusNotifier {
  @override
  OnboardingStatus build() => const OnboardingStatusLoaded(true);
}

class FakeUnauthenticatedNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _FakeIncompleteOnboardingNotifier extends OnboardingStatusNotifier {
  @override
  OnboardingStatus build() => const OnboardingStatusLoaded(false);
}

/// Boots the app straight into the authenticated shell — the real
/// [AuthStateAwareRedirectPolicy] still runs and still does the
/// splash→home redirect, only the underlying auth/onboarding state is
/// faked, so this exercises real routing rather than bypassing it.
List<Override> authenticatedTestOverrides() => [
  authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
  onboardingStatusProvider.overrideWith(FakeCompletedOnboardingNotifier.new),
];

/// Same idea, unauthenticated — for exercising the redirect policy's
/// onboarding/sign-in branches without touching real storage.
List<Override> unauthenticatedTestOverrides({
  required bool onboardingCompleted,
}) => [
  authStateNotifierProvider.overrideWith(FakeUnauthenticatedNotifier.new),
  onboardingStatusProvider.overrideWith(
    onboardingCompleted
        ? FakeCompletedOnboardingNotifier.new
        : _FakeIncompleteOnboardingNotifier.new,
  ),
];
