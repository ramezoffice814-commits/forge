import 'package:flutter/material.dart';

import '../../domain/progress/mission_progress_state.dart';
import 'progress_controls/binary_progress_control.dart';
import 'progress_controls/checklist_progress_control.dart';
import 'progress_controls/coding_session_progress_control.dart';
import 'progress_controls/counter_progress_control.dart';
import 'progress_controls/hydration_progress_control.dart';
import 'progress_controls/percentage_progress_control.dart';
import 'progress_controls/progress_update_callback.dart';
import 'progress_controls/quantity_progress_control.dart';
import 'progress_controls/reading_progress_control.dart';
import 'progress_controls/reflection_progress_control.dart';
import 'progress_controls/timer_progress_control.dart';

/// Dispatches to the one reusable control that matches the mission's
/// [MissionProgressType] — new progress types are added by adding a case
/// here and a corresponding control widget, never by branching UI logic
/// elsewhere in the page.
class MissionProgressControl extends StatelessWidget {
  const MissionProgressControl({
    super.key,
    required this.progress,
    required this.onUpdate,
    this.enabled = true,
  });

  final MissionProgressState progress;
  final ProgressUpdateCallback onUpdate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final state = progress;
    return switch (state) {
      BinaryProgressState() => BinaryProgressControl(
        state: state,
        onUpdate: onUpdate,
        enabled: enabled,
      ),
      CounterProgressState() => CounterProgressControl(
        state: state,
        onUpdate: onUpdate,
        enabled: enabled,
      ),
      TimerProgressState() => TimerProgressControl(
        state: state,
        onUpdate: onUpdate,
        enabled: enabled,
      ),
      ChecklistProgressState() => ChecklistProgressControl(
        state: state,
        onUpdate: onUpdate,
        enabled: enabled,
      ),
      PercentageProgressState() => PercentageProgressControl(
        state: state,
        onUpdate: onUpdate,
        enabled: enabled,
      ),
      QuantityProgressState() => QuantityProgressControl(
        state: state,
        onUpdate: onUpdate,
        enabled: enabled,
      ),
      ReflectionProgressState() => ReflectionProgressControl(
        state: state,
        onUpdate: onUpdate,
        enabled: enabled,
      ),
      ReadingProgressState() => ReadingProgressControl(
        state: state,
        onUpdate: onUpdate,
        enabled: enabled,
      ),
      CodingSessionProgressState() => CodingSessionProgressControl(
        state: state,
        onUpdate: onUpdate,
        enabled: enabled,
      ),
      HydrationProgressState() => HydrationProgressControl(
        state: state,
        onUpdate: onUpdate,
        enabled: enabled,
      ),
    };
  }
}
