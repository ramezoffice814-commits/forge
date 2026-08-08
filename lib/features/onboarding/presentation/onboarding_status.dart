/// Loading state for the device-local onboarding-completion flag. Kept
/// distinct from "loaded, not completed" so the router redirect can tell
/// "still reading storage" apart from "read it, user hasn't onboarded".
sealed class OnboardingStatus {
  const OnboardingStatus();
}

class OnboardingStatusLoading extends OnboardingStatus {
  const OnboardingStatusLoading();
}

class OnboardingStatusLoaded extends OnboardingStatus {
  const OnboardingStatusLoaded(this.completed);

  final bool completed;
}
