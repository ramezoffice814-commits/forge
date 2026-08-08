import 'package:flutter/material.dart';

import '../../../../../core/theme/forge_tokens.dart';
import '../../../domain/progress/mission_progress_state.dart';
import '../../../../../shared/widgets/forge_button.dart';
import 'progress_update_callback.dart';

/// The actual reflection text never leaves this widget — only
/// `responseLength`/`responsePresent` are ever sent upward into a
/// `MissionProgressUpdated` event (see `ReflectionProgressState`'s own doc
/// comment). Typing is not synced live; "Save" is the one discrete action
/// that reports progress, so no event is appended per keystroke.
class ReflectionProgressControl extends StatefulWidget {
  const ReflectionProgressControl({
    super.key,
    required this.state,
    required this.onUpdate,
    this.enabled = true,
  });

  final ReflectionProgressState state;
  final ProgressUpdateCallback onUpdate;
  final bool enabled;

  @override
  State<ReflectionProgressControl> createState() =>
      _ReflectionProgressControlState();
}

class _ReflectionProgressControlState extends State<ReflectionProgressControl> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    widget.onUpdate(
      ReflectionProgressState(
        minimumLength: widget.state.minimumLength,
        responseLength: text.length,
        responsePresent: text.isNotEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.state.responsePresent
              ? 'Saved (${widget.state.responseLength} characters, '
                    'minimum ${widget.state.minimumLength})'
              : 'Nothing saved yet (minimum ${widget.state.minimumLength} '
                    'characters)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        SizedBox(height: tokens.spacing.space2),
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Write your reflection…'),
        ),
        SizedBox(height: tokens.spacing.space2),
        Align(
          alignment: Alignment.centerRight,
          child: ForgeButton(
            label: 'Save reflection',
            onPressed: widget.enabled ? _save : null,
          ),
        ),
      ],
    );
  }
}
