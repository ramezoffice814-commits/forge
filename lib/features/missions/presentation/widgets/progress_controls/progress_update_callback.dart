import '../../../domain/progress/mission_progress_state.dart';

/// Every progress control reports through this shape rather than calling
/// `MissionLifecycleController.updateProgress` directly — keeps the
/// controls themselves free of any provider/controller dependency, so
/// they're plain, easily-tested widgets.
typedef ProgressUpdateCallback =
    void Function(MissionProgressState proposed, {bool isCorrection});
