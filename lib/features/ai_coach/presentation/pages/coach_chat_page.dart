import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/forge_tokens.dart';
import '../../domain/enums/ai_privacy_level.dart';
import '../providers/ai_coach_providers.dart';
import '../providers/coach_chat_controller.dart';

/// Roadmap Item 14 section 20: the minimal coach chat surface. Messages
/// live only for this page's lifetime — see
/// `CoachChatController`'s doc comment for why nothing here is
/// persisted.
class CoachChatPage extends ConsumerStatefulWidget {
  const CoachChatPage({super.key, required this.displayName});

  final String displayName;

  @override
  ConsumerState<CoachChatPage> createState() => _CoachChatPageState();
}

class _CoachChatPageState extends ConsumerState<CoachChatPage> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await ref
          .read(coachChatControllerProvider.notifier)
          .send(text, displayName: widget.displayName);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final privacyLevel = ref.watch(aiPrivacyLevelProvider);
    final messages = ref.watch(coachChatControllerProvider);

    if (privacyLevel == AiPrivacyLevel.disabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Coach')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.space3),
            child: Text(
              'AI coaching is turned off. You can re-enable it in privacy settings.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(tokens.spacing.space2),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isUser = message.sender == CoachChatSender.user;
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(bottom: tokens.spacing.space1),
                    padding: EdgeInsets.all(tokens.spacing.space2),
                    decoration: BoxDecoration(
                      color: isUser
                          ? tokens.accent.withValues(alpha: 0.15)
                          : tokens.surface,
                      borderRadius: tokens.radius.mdRadius,
                    ),
                    child: Text(message.text),
                  ),
                );
              },
            ),
          ),
          if (_sending)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.space1),
              child: Text(
                'The Watcher is thinking…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.text.withValues(alpha: 0.5),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(tokens.spacing.space2),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask the Watcher…',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sending ? null : _send,
                  tooltip: 'Send',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
