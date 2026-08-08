import '../../domain/entities/dialogue_line.dart';

/// Pure line-advance logic for a transmission's dialogue — no timers, no
/// Flutter, no TTS. [DailyTransmissionController] owns *when* to advance
/// (TTS completion or estimated-duration fallback); this class only answers
/// "what line is at this index" and "what does progress/the transcript
/// look like", so that logic is unit-testable without any async plumbing.
class SubtitleSequencer {
  const SubtitleSequencer(this.lines);

  final List<DialogueLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get lastIndex => lines.length - 1;

  DialogueLine? lineAt(int index) {
    if (index < 0 || index >= lines.length) return null;
    return lines[index];
  }

  bool isLast(int index) => index >= lastIndex;

  int nextIndex(int index) => index + 1;

  /// 0–1 fraction of lines shown so far (line-count based, not a live
  /// per-line timer — deliberately: a continuously ticking progress bar
  /// would be exactly the kind of always-on animation the character engine
  /// is required to avoid).
  double lineProgress(int index) {
    if (lines.isEmpty) return 1;
    final shown = (index + 1).clamp(0, lines.length);
    return shown / lines.length;
  }

  String get transcript => lines.map((l) => l.text).join('\n\n');
}
