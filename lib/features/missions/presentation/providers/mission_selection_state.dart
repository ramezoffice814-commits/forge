import 'package:flutter/foundation.dart';

import '../../domain/entities/mission_selection_result.dart';

@immutable
sealed class MissionSelectionState {
  const MissionSelectionState();
}

class MissionSelectionLoading extends MissionSelectionState {
  const MissionSelectionLoading();
}

@immutable
class MissionSelectionReady extends MissionSelectionState {
  const MissionSelectionReady(this.result);

  final MissionSelectionResult result;
}

@immutable
class MissionSelectionError extends MissionSelectionState {
  const MissionSelectionError(this.message);

  final String message;
}
