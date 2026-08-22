import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/enums/ai_privacy_level.dart';
import '../providers/ai_coach_providers.dart';

class DailyTransmissionAiLineParams {
  const DailyTransmissionAiLineParams({
    required this.displayName,
    required this.isRecoveryMode,
    required this.activeDaysThisWeek,
    required this.consistencySummary,
  });

  final String displayName;
  final bool isRecoveryMode;
  final int activeDaysThisWeek;
  final String consistencySummary;

  @override
  bool operator ==(Object other) =>
      other is DailyTransmissionAiLineParams &&
      other.displayName == displayName &&
      other.isRecoveryMode == isRecoveryMode &&
      other.activeDaysThisWeek == activeDaysThisWeek &&
      other.consistencySummary == consistencySummary;

  @override
  int get hashCode => Object.hash(
    displayName,
    isRecoveryMode,
    activeDaysThisWeek,
    consistencySummary,
  );
}

final dailyTransmissionAiLineProvider = FutureProvider.autoDispose
    .family<String?, DailyTransmissionAiLineParams>((ref, params) async {
      final privacyLevel = ref.watch(aiPrivacyLevelProvider);
      if (privacyLevel == AiPrivacyLevel.disabled) return null;
      final personalization = ref.watch(aiPersonalizationProfileProvider);
      final useCase = ref.watch(getDailyTransmissionDialogueUseCaseProvider);
      final response = await useCase(
        privacyLevel: privacyLevel,
        displayName: params.displayName,
        isRecoveryMode: params.isRecoveryMode,
        activeDaysThisWeek: params.activeDaysThisWeek,
        consistencySummary: params.consistencySummary,
        personalization: personalization,
      );
      return response.message;
    });

/// An additive line the Daily Transmission screen may optionally render
/// (Roadmap Item 14 section 20) alongside the existing, separately
/// tested mock-script dialogue — this widget never touches
/// `DailyTransmissionController` or its state machine, so embedding it
/// (or not) on that screen carries zero risk to the existing, timing-
/// sensitive TTS/animation test suite. Renders nothing while loading,
/// on error, or when AI coaching is disabled.
class DailyTransmissionAiLine extends ConsumerWidget {
  const DailyTransmissionAiLine({
    super.key,
    required this.displayName,
    required this.isRecoveryMode,
    required this.activeDaysThisWeek,
    required this.consistencySummary,
  });

  final String displayName;
  final bool isRecoveryMode;
  final int activeDaysThisWeek;
  final String consistencySummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final line = ref.watch(
      dailyTransmissionAiLineProvider(
        DailyTransmissionAiLineParams(
          displayName: displayName,
          isRecoveryMode: isRecoveryMode,
          activeDaysThisWeek: activeDaysThisWeek,
          consistencySummary: consistencySummary,
        ),
      ),
    );

    return line.when(
      data: (message) {
        if (message == null) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(top: tokens.spacing.space1),
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
