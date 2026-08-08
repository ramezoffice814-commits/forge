/// Device-local "has this install seen onboarding" flag. Deliberately
/// separate from [AuthUser.onboardingCompleted]: onboarding runs *before*
/// any account exists, so its completion has to be knowable without an
/// authenticated user.
abstract class OnboardingRepository {
  Future<bool> isCompleted();
  Future<void> markCompleted();
}
