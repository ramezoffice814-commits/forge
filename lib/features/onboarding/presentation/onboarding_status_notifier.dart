import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_onboarding_repository.dart';
import 'onboarding_status.dart';

class OnboardingStatusNotifier extends Notifier<OnboardingStatus> {
  @override
  OnboardingStatus build() {
    _load();
    return const OnboardingStatusLoading();
  }

  Future<void> _load() async {
    final completed = await ref
        .read(onboardingRepositoryProvider)
        .isCompleted();
    state = OnboardingStatusLoaded(completed);
  }

  Future<void> markCompleted() async {
    await ref.read(onboardingRepositoryProvider).markCompleted();
    state = const OnboardingStatusLoaded(true);
  }
}

final onboardingStatusProvider =
    NotifierProvider<OnboardingStatusNotifier, OnboardingStatus>(
      OnboardingStatusNotifier.new,
    );
