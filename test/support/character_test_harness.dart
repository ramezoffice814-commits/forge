import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge/core/storage/secure_key_value_store.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:forge/features/ai_coach/domain/enums/ai_privacy_level.dart';
import 'package:forge/features/ai_coach/presentation/providers/ai_coach_providers.dart';
import 'package:forge/features/auth/presentation/auth_state_notifier.dart';
import 'package:forge/features/character/data/mock/fake_character_animation_controller.dart';
import 'package:forge/features/character/data/mock/fake_tts_service.dart';
import 'package:forge/features/character/data/transmission_repository_provider.dart';
import 'package:forge/features/character/data/tts_service_provider.dart';
import 'package:forge/features/character/domain/services/tts_service.dart';
import 'package:forge/features/character/presentation/controllers/daily_transmission_controller.dart';
import 'package:forge/features/character/presentation/daily_transmission_page.dart';

import 'fake_auth_overrides.dart';
import 'fake_dashboard_overrides.dart';
import 'fake_secure_key_value_store.dart';
import 'fast_transmission_repository.dart';

/// Everything a character-feature test needs wired up: a synchronously
/// populated dashboard (so `DailyTransmissionController.start()` finds it
/// ready — see `fake_dashboard_overrides.dart`), a controllable
/// [FakeTtsService], and an instant [FakeCharacterAnimationController] so
/// tests don't pay real wall-clock time for one-shot animation playback.
class TransmissionTestHarness {
  TransmissionTestHarness({FakeTtsService? tts})
    : tts = tts ?? FakeTtsService();

  final FakeTtsService tts;

  List<Override> overrides({
    TransmissionMockScenario scenario = TransmissionMockScenario.normalActive,
    List<Override> extra = const [],
  }) {
    return [
      secureKeyValueStoreProvider.overrideWithValue(FakeSecureKeyValueStore()),
      authStateNotifierProvider.overrideWith(FakeAuthenticatedNotifier.new),
      ...dashboardPopulatedOverrides(),
      transmissionRepositoryProvider.overrideWithValue(
        fastMockTransmissionRepository(scenario),
      ),
      ttsServiceProvider.overrideWithValue(tts as TtsService),
      characterAnimationControllerFactoryProvider.overrideWithValue(
        FakeCharacterAnimationController.new,
      ),
      // Character/transmission tests pin dialogue content via
      // `TransmissionMockScenario`, not AI-generated text — disabling
      // AI here keeps that content the deterministic thing under test.
      // A test that specifically wants to exercise the AI line can
      // still override this back via `extra`.
      aiPrivacyLevelProvider.overrideWith((ref) => AiPrivacyLevel.disabled),
      ...extra,
    ];
  }

  Widget page({
    TransmissionMockScenario scenario = TransmissionMockScenario.normalActive,
    bool reducedMotion = false,
    double textScale = 1.0,
    List<Override> extra = const [],
  }) {
    return ProviderScope(
      overrides: overrides(scenario: scenario, extra: extra),
      child: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reducedMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: ForgeTheme.dark(),
          home: const DailyTransmissionPage(),
        ),
      ),
    );
  }
}
