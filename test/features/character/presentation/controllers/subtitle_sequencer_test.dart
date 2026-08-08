import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/character/domain/entities/dialogue_line.dart';
import 'package:forge/features/character/presentation/controllers/subtitle_sequencer.dart';

void main() {
  final lines = [
    const DialogueLine(
      id: 'a',
      text: 'First line.',
      estimatedDuration: Duration(seconds: 1),
    ),
    const DialogueLine(
      id: 'b',
      text: 'Second line.',
      estimatedDuration: Duration(seconds: 1),
    ),
    const DialogueLine(
      id: 'c',
      text: 'Third line.',
      estimatedDuration: Duration(seconds: 1),
    ),
  ];

  test('lineAt returns null out of range, the line in range', () {
    final sequencer = SubtitleSequencer(lines);
    expect(sequencer.lineAt(-1), isNull);
    expect(sequencer.lineAt(3), isNull);
    expect(sequencer.lineAt(1)!.id, 'b');
  });

  test('lastIndex and isLast', () {
    final sequencer = SubtitleSequencer(lines);
    expect(sequencer.lastIndex, 2);
    expect(sequencer.isLast(2), isTrue);
    expect(sequencer.isLast(1), isFalse);
  });

  test('nextIndex simply increments', () {
    final sequencer = SubtitleSequencer(lines);
    expect(sequencer.nextIndex(0), 1);
  });

  test('lineProgress is line-count based, clamped to [0,1]', () {
    final sequencer = SubtitleSequencer(lines);
    expect(sequencer.lineProgress(-1), 0);
    expect(sequencer.lineProgress(0), closeTo(1 / 3, 0.001));
    expect(sequencer.lineProgress(2), 1);
  });

  test('transcript joins every line with a blank line between', () {
    final sequencer = SubtitleSequencer(lines);
    expect(sequencer.transcript, 'First line.\n\nSecond line.\n\nThird line.');
  });

  test('empty sequencer reports isEmpty and full progress', () {
    const sequencer = SubtitleSequencer([]);
    expect(sequencer.isEmpty, isTrue);
    expect(sequencer.lineProgress(0), 1);
    expect(sequencer.transcript, '');
  });
}
