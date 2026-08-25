import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/achievements/presentation/achievements_page.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/character/presentation/daily_transmission_page.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/auth/presentation/sign_up_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/leaderboard/presentation/leaderboard_page.dart';
import '../../features/missions/presentation/pages/active_mission_page.dart';
import '../../features/notifications/presentation/pages/notification_inbox_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/progress/presentation/progress_page.dart';
import '../../features/social/presentation/pages/public_profile_page.dart';
import '../../features/social/presentation/pages/social_page.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'auth_redirect_policy.dart';
import 'not_found_page.dart';
import 'router_refresh_listenable.dart';

/// Root [GoRouter] config. Public routes (splash/onboarding/sign-in/
/// sign-up/forgot-password) sit as top-level siblings of the protected
/// [StatefulShellRoute.indexedStack] — they intentionally don't show the
/// bottom nav. [AuthStateAwareRedirectPolicy] gates everything;
/// [RouterRefreshListenable] re-runs that redirect whenever auth or
/// onboarding state actually changes (e.g. session-restore completing),
/// so navigation follows state changes without any screen calling
/// `context.go` itself.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authRedirect = ref.watch(authRedirectPolicyProvider);
  final refreshListenable = RouterRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: AppRoutePaths.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) => authRedirect.redirect(context, state),
    errorBuilder: (context, state) =>
        NotFoundPage(message: "No route for '${state.uri}'."),
    routes: [
      GoRoute(
        path: AppRoutePaths.splash,
        name: AppRouteNames.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutePaths.onboarding,
        name: AppRouteNames.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutePaths.signIn,
        name: AppRouteNames.signIn,
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: AppRoutePaths.signUp,
        name: AppRouteNames.signUp,
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: AppRoutePaths.forgotPassword,
        name: AppRouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      // Deliberately a top-level route rather than nested under the home
      // branch: it needs the full screen (no bottom nav) and a plain push
      // onto the root Navigator is all the back-button/back-gesture
      // behavior this needs — no reason to complicate the shell's
      // IndexedStack branches for it.
      GoRoute(
        path: AppRoutePaths.dailyTransmission,
        name: AppRouteNames.dailyTransmission,
        builder: (context, state) => const DailyTransmissionPage(),
      ),
      // Same full-screen-on-top-of-the-shell reasoning as
      // `dailyTransmission` above — see `ActiveMissionPage`.
      GoRoute(
        path: AppRoutePaths.activeMissionPattern,
        name: AppRouteNames.activeMission,
        builder: (context, state) => ActiveMissionPage(
          missionInstanceId: state.pathParameters['missionInstanceId']!,
        ),
      ),
      // Same reasoning again — see `SocialPage`/`PublicProfilePage`.
      GoRoute(
        path: AppRoutePaths.social,
        name: AppRouteNames.social,
        builder: (context, state) => const SocialPage(),
      ),
      GoRoute(
        path: AppRoutePaths.publicProfilePattern,
        name: AppRouteNames.publicProfile,
        builder: (context, state) =>
            PublicProfilePage(userId: state.pathParameters['userId']!),
      ),
      // Same reasoning again — see `NotificationInboxPage`.
      GoRoute(
        path: AppRoutePaths.notifications,
        name: AppRouteNames.notifications,
        builder: (context, state) => const NotificationInboxPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutePaths.home,
                name: AppRouteNames.home,
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutePaths.rank,
                name: AppRouteNames.rank,
                builder: (context, state) => const LeaderboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutePaths.progress,
                name: AppRouteNames.progress,
                builder: (context, state) => const ProgressPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutePaths.awards,
                name: AppRouteNames.awards,
                builder: (context, state) => const AchievementsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutePaths.profile,
                name: AppRouteNames.profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
