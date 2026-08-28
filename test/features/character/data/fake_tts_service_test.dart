import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/character/data/mock/fake_tts_service.dart';
import 'package:forge/features/character/domain/services/tts_service.dart';

void main() {
  test('unavailable until initialize() runs', () async {
    final tts = FakeTtsService();
    expect(tts.isAvailable, isFalse);
    await tts.initialize();
    expect(tts.isAvailable, isTrue);
  });

  test(
    'simulateUnavailable keeps isAvailable false after initialize()',
    () async {
      final tts = FakeTtsService(simulateUnavailable: true);
      await tts.initialize();
      expect(tts.isAvailable, isFalse);

      // speak() must still be a safe no-op, not throw or hang.
      await tts.speak('hello');
      expect(tts.spokenTexts, ['hello']);
    },
  );

  test('speak() auto-completes and records the text', () async {
    final tts = FakeTtsService();
    await tts.initialize();
    await tts.speak('Ramez, the current is ready.');
    expect(tts.spokenTexts, ['Ramez, the current is ready.']);
    expect(tts.state, TtsPlaybackState.stopped);
  });

  test(
    'manual completion mode holds speak() until completeCurrentSpeech()',
    () async {
      final tts = FakeTtsService(autoComplete: false);
      await tts.initialize();

      var completed = false;
      final future = tts.speak('line one').then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(tts.state, TtsPlaybackState.speaking);

      tts.completeCurrentSpeech();
      await future;
      expect(completed, isTrue);
      expect(tts.state, TtsPlaybackState.stopped);
    },
  );

  test('stop() resolves a pending speak() immediately', () async {
    final tts = FakeTtsService(autoComplete: false);
    await tts.initialize();

    final future = tts.speak('line one');
    await tts.stop();
    await future;

    expect(tts.stopCalls, 1);
    expect(tts.state, TtsPlaybackState.stopped);
  });

  test('dispose() marks disposed and resolves pending speech', () async {
    final tts = FakeTtsService(autoComplete: false);
    await tts.initialize();
    final future = tts.speak('line one');

    await tts.dispose();
    await future;

    expect(tts.disposed, isTrue);
  });
}
