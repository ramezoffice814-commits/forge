import 'package:forge/features/character/data/mock/mock_transmission_repository.dart';
import 'package:forge/features/character/domain/entities/dialogue_line.dart';
import 'package:forge/features/character/domain/entities/transmission_script.dart';
import 'package:forge/features/character/domain/repositories/transmission_repository.dart';
import 'package:forge/features/dashboard/domain/entities/dashboard_overview.dart';

/// Wraps a real [TransmissionRepository] and rewrites every dialogue line's
/// timing to near-zero while keeping the real text/mission content intact.
///
/// `pumpAndSettle()` only keeps pumping while a frame is actively
/// scheduled; a bare `Future.delayed` gap (this feature's `pauseAfter` and
/// estimated-duration pacing) has nothing scheduled *while it's ticking*,
/// so `pumpAndSettle` can decide the widget tree has "settled" and return
/// before that real (900ms–6000ms in the production scripts) timer ever
/// fires — leaving it pending at test teardown, which Flutter's test
/// framework treats as a failure. Removing the real timing here (rather
/// than working around `pumpAndSettle`) keeps widget/golden/integration
/// tests fast and lets `pumpAndSettle()` behave normally.
class FastTransmissionRepository implements TransmissionRepository {
  const FastTransmissionRepository(this._inner);

  final TransmissionRepository _inner;

  @override
  Future<TransmissionScript> getDailyTransmission(
    DashboardOverview dashboard,
  ) async {
    final script = await _inner.getDailyTransmission(dashboard);
    return TransmissionScript(
      id: script.id,
      characterId: script.characterId,
      date: script.date,
      introLabel: script.introLabel,
      dialogueLines: [for (final line in script.dialogueLines) _fast(line)],
      missionTitle: script.missionTitle,
      missionDescription: script.missionDescription,
      category: script.category,
      difficulty: script.difficulty,
      estimatedMinutes: script.estimatedMinutes,
      xpReward: script.xpReward,
      requiresProof: script.requiresProof,
      completionConditions: script.completionConditions,
      closingDialogue: script.closingDialogue?.map(_fast).toList(),
      accessibilitySummary: script.accessibilitySummary,
    );
  }

  static DialogueLine _fast(DialogueLine line) {
    return DialogueLine(
      id: line.id,
      text: line.text,
      estimatedDuration: const Duration(milliseconds: 10),
      pauseAfter: Duration.zero,
      emotionalState: line.emotionalState,
      emphasisWords: line.emphasisWords,
    );
  }
}

/// Convenience: a real [MockTransmissionRepository] for [scenario], wrapped
/// to run with near-zero timing.
FastTransmissionRepository fastMockTransmissionRepository(
  TransmissionMockScenario scenario,
) {
  return FastTransmissionRepository(
    MockTransmissionRepository(scenario: scenario),
  );
}
