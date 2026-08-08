import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_state_notifier.dart';
import '../../features/onboarding/presentation/onboarding_status_notifier.dart';

/// Bridges Riverpod state changes to [GoRouter]'s `refreshListenable`, so
/// a redirect decision that depended on "still restoring" gets
/// re-evaluated the moment auth/onboarding state actually resolves —
/// without this, [SplashPage] would never navigate away on its own.
class RouterRefreshListenable extends ChangeNotifier {
  RouterRefreshListenable(Ref ref) {
    ref.listen(
      authStateNotifierProvider,
      (previous, next) => notifyListeners(),
    );
    ref.listen(onboardingStatusProvider, (previous, next) => notifyListeners());
  }
}
