import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_coach_providers.dart';

enum CoachChatSender { user, watcher }

@immutable
class CoachChatMessage {
  const CoachChatMessage({required this.sender, required this.text});

  final CoachChatSender sender;
  final String text;
}

/// Session-only chat state (Roadmap Item 14 section 24: "never persisted
/// longer than the active chat session") — deliberately an in-memory
/// list with no repository/storage backing. Disposed when the chat
/// screen closes; nothing here survives an app restart by design.
class CoachChatController extends AutoDisposeNotifier<List<CoachChatMessage>> {
  @override
  List<CoachChatMessage> build() => const [];

  Future<void> send(String text, {required String displayName}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    state = [
      ...state,
      CoachChatMessage(sender: CoachChatSender.user, text: trimmed),
    ];

    final privacyLevel = ref.read(aiPrivacyLevelProvider);
    final personalization = ref.read(aiPersonalizationProfileProvider);
    final useCase = ref.read(sendCoachChatMessageUseCaseProvider);

    final response = await useCase(
      privacyLevel: privacyLevel,
      displayName: displayName,
      userMessage: trimmed,
      personalization: personalization,
    );

    state = [
      ...state,
      CoachChatMessage(sender: CoachChatSender.watcher, text: response.message),
    ];
  }
}

final coachChatControllerProvider =
    AutoDisposeNotifierProvider<CoachChatController, List<CoachChatMessage>>(
      CoachChatController.new,
    );
