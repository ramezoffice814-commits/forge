/// Route path constants — never hardcode a route string at a call site.
abstract final class AppRoutePaths {
  // Public
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';

  // Protected (behind the bottom-nav shell)
  static const home = '/home';
  static const rank = '/rank';
  static const progress = '/progress';
  static const awards = '/awards';
  static const profile = '/profile';

  // Protected, but pushed full-screen on top of the shell rather than a
  // bottom-nav tab — see `DailyTransmissionPage`'s doc comment for why.
  static const dailyTransmission = '/home/transmission';

  // Same "full-screen, pushed on top of the shell" reasoning as
  // `dailyTransmission` — see `ActiveMissionPage`. `:missionInstanceId` is a
  // path parameter, so `AuthStateAwareRedirectPolicy` matches it by prefix
  // (see [activeMissionPrefix]) rather than by exact string.
  static const activeMissionPattern = '/home/mission/:missionInstanceId';
  static const activeMissionPrefix = '/home/mission/';

  static String activeMission(String missionInstanceId) =>
      '$activeMissionPrefix$missionInstanceId';

  static const protected = [
    home,
    rank,
    progress,
    awards,
    profile,
    dailyTransmission,
  ];
  static const publicAuthRoutes = [signIn, signUp, forgotPassword];
}

/// Route name constants, for `context.goNamed`/`context.pushNamed` call
/// sites once deep-linking within a tab is needed.
abstract final class AppRouteNames {
  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const signIn = 'sign-in';
  static const signUp = 'sign-up';
  static const forgotPassword = 'forgot-password';

  static const home = 'home';
  static const rank = 'rank';
  static const progress = 'progress';
  static const awards = 'awards';
  static const profile = 'profile';
  static const dailyTransmission = 'daily-transmission';
  static const activeMission = 'active-mission';
}
