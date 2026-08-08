import '../../../dashboard/domain/entities/mission_preview.dart';
import '../../domain/entities/character_id.dart';
import '../../domain/entities/character_state.dart';
import '../../domain/entities/dialogue_line.dart';
import '../../domain/entities/transmission_script.dart';

/// Hand-authored, deterministic Watcher dialogue — no randomness, no AI
/// generation. [displayName] is interpolated here (not inside any widget)
/// so presentation code never hardcodes a user's name.
///
/// Mission *facts* (title/description/category/difficulty/minutes/xp/
/// proof/completion conditions) are never authored here — they're read
/// straight from the [MissionPreview] the Dashboard already resolved via
/// the mission-selection engine (see `mission_preview_adapter.dart`), so
/// the two presentations of "today's mission" can never disagree.
abstract final class MockTransmissionScripts {
  static final DateTime referenceDate = DateTime.utc(2026, 8, 5);

  /// ~185ms/word plus a fixed floor, clamped to a sane ceiling — a stand-in
  /// for real speech timing used only when TTS can't drive pacing itself.
  static Duration _pace(String text) {
    final words = text.trim().split(RegExp(r'\s+')).length;
    final ms = 900 + words * 185;
    return Duration(milliseconds: ms.clamp(900, 6000));
  }

  static DialogueLine _line(
    String id,
    String text, {
    CharacterState? emotionalState,
    Duration pauseAfter = const Duration(milliseconds: 450),
  }) {
    return DialogueLine(
      id: id,
      text: text,
      estimatedDuration: _pace(text),
      pauseAfter: pauseAfter,
      emotionalState: emotionalState,
    );
  }

  static List<String> _completionConditions(MissionPreview mission) {
    return mission.completionConditions.isNotEmpty
        ? mission.completionConditions
        : ['Complete the mission as described'];
  }

  static TransmissionScript normalActive(
    String displayName,
    MissionPreview mission,
  ) {
    return TransmissionScript(
      id: 'transmission-normal-active',
      characterId: CharacterId.watcher,
      date: referenceDate,
      introLabel: 'Incoming Transmission',
      dialogueLines: [
        _line('n1', '$displayName… the forge is ready.'),
        _line(
          'n2',
          'Yesterday showed consistency.',
          emotionalState: CharacterState.proud,
        ),
        _line('n3', "Today's trial is simple, but not easy."),
        _line('n4', mission.title),
        _line('n5', 'Return when the work is done.', pauseAfter: Duration.zero),
      ],
      missionTitle: mission.title,
      missionDescription: mission.subtitle,
      category: mission.category,
      difficulty: mission.difficulty,
      estimatedMinutes: mission.estimatedMinutes,
      xpReward: mission.xpReward,
      requiresProof: mission.requiresProof,
      completionConditions: _completionConditions(mission),
      accessibilitySummary:
          'The Watcher notes your consistency and assigns today\'s mission: '
          '${mission.title}, worth ${mission.xpReward} XP.',
    );
  }

  static TransmissionScript firstDay(
    String displayName,
    MissionPreview mission,
  ) {
    return TransmissionScript(
      id: 'transmission-first-day',
      characterId: CharacterId.watcher,
      date: referenceDate,
      introLabel: 'First Transmission',
      dialogueLines: [
        _line('f1', 'Welcome to the Forge, $displayName.'),
        _line('f2', 'Your first mission is deliberately small.'),
        _line(
          'f3',
          'Discipline begins with one completed promise.',
          pauseAfter: Duration.zero,
        ),
      ],
      missionTitle: mission.title,
      missionDescription: mission.subtitle,
      category: mission.category,
      difficulty: mission.difficulty,
      estimatedMinutes: mission.estimatedMinutes,
      xpReward: mission.xpReward,
      requiresProof: mission.requiresProof,
      completionConditions: _completionConditions(mission),
      accessibilitySummary:
          'The Watcher welcomes you to the Forge and assigns a small first '
          'mission: ${mission.title}, worth ${mission.xpReward} XP.',
    );
  }

  static TransmissionScript recovery(
    String displayName,
    MissionPreview mission,
  ) {
    return TransmissionScript(
      id: 'transmission-recovery',
      characterId: CharacterId.watcher,
      date: referenceDate,
      introLabel: 'Incoming Transmission',
      dialogueLines: [
        _line(
          'r1',
          'Today is not about proving everything, $displayName.',
          emotionalState: CharacterState.concerned,
        ),
        _line('r2', 'One achievable mission is enough.'),
        _line('r3', 'Rebuild the rhythm.', pauseAfter: Duration.zero),
      ],
      missionTitle: mission.title,
      missionDescription: mission.subtitle,
      category: mission.category,
      difficulty: mission.difficulty,
      estimatedMinutes: mission.estimatedMinutes,
      xpReward: mission.xpReward,
      requiresProof: mission.requiresProof,
      completionConditions: _completionConditions(mission),
      accessibilitySummary:
          'The Watcher offers a gentle recovery mission: ${mission.title}, '
          'worth ${mission.xpReward} XP.',
    );
  }

  static TransmissionScript completedReplay(
    String displayName,
    MissionPreview mission,
  ) {
    return TransmissionScript(
      id: 'transmission-completed-replay',
      characterId: CharacterId.watcher,
      date: referenceDate,
      introLabel: 'Transmission Replay',
      dialogueLines: [
        _line(
          'c1',
          'The mission is already complete.',
          emotionalState: CharacterState.proud,
        ),
        _line(
          'c2',
          'Remember the effort that brought you here.',
          pauseAfter: Duration.zero,
        ),
      ],
      missionTitle: mission.title,
      missionDescription: mission.subtitle,
      category: mission.category,
      difficulty: mission.difficulty,
      estimatedMinutes: mission.estimatedMinutes,
      xpReward: mission.xpReward,
      requiresProof: mission.requiresProof,
      completionConditions: _completionConditions(mission),
      accessibilitySummary:
          "The Watcher confirms today's mission is already complete.",
    );
  }
}
