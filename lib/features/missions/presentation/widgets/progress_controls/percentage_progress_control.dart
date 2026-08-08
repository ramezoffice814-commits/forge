import 'package:flutter/material.dart';

import '../../../../../core/theme/forge_tokens.dart';
import '../../../domain/progress/mission_progress_state.dart';
import 'progress_update_callback.dart';

/// Uses `onChangeEnd` rather than `onChanged` so dragging the slider never
/// fires a progress update per frame — only the settled value is recorded.
class PercentageProgressControl extends StatefulWidget {
  const PercentageProgressControl({
    super.key,
    required this.state,
    required this.onUpdate,
    this.enabled = true,
  });

  final PercentageProgressState state;
  final ProgressUpdateCallback onUpdate;
  final bool enabled;

  @override
  State<PercentageProgressControl> createState() =>
      _PercentageProgressControlState();
}

class _PercentageProgressControlState extends State<PercentageProgressControl> {
  late double _liveValue = widget.state.percentage;

  @override
  void didUpdateWidget(covariant PercentageProgressControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.percentage != widget.state.percentage) {
      _liveValue = widget.state.percentage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_liveValue.round()}% complete',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          value: _liveValue.clamp(0, 100),
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: tokens.accent,
          onChanged: widget.enabled
              ? (value) => setState(() => _liveValue = value)
              : null,
          onChangeEnd: widget.enabled
              ? (value) => widget.onUpdate(
                  PercentageProgressState(
                    percentage: value,
                    thresholdPercentage: widget.state.thresholdPercentage,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}
