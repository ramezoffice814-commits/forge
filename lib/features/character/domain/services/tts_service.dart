/// Playback status a [TtsService] can report through [TtsService.state].
enum TtsPlaybackState { stopped, speaking, paused }

/// Thrown by [TtsService.speak] (or surfaced via [TtsService.initialize])
/// when speech genuinely could not happen — engine missing, no voices
/// installed, platform unsupported. Callers must treat this as
/// non-fatal: subtitles keep working without audio.
class TtsUnavailableException implements Exception {
  const TtsUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'TtsUnavailableException: $message';
}

/// Abstraction over a local, on-device text-to-speech engine. Deliberately
/// narrow — no cloud TTS, no voice cloning, system voices only. Consumers
/// (the transmission controller) must keep working — subtitles included —
/// even when every method here throws or silently does nothing.
abstract class TtsService {
  /// Prepares the engine and default voice. Must not throw for "no voices
  /// installed" — callers rely on [isAvailable] afterward instead.
  Future<void> initialize();

  /// True once [initialize] has run and speech is expected to work. When
  /// false, [speak] is expected to still return without throwing (a no-op)
  /// so callers never need to guard every call site.
  bool get isAvailable;

  TtsPlaybackState get state;

  /// Speaks [text] and completes when playback finishes naturally. Completes
  /// immediately (without speaking) if [isAvailable] is false. Never leaves
  /// the returned future unresolved forever — a stuck engine must not hang
  /// the caller.
  Future<void> speak(String text);

  /// Stops any in-flight speech immediately. Safe to call when idle.
  Future<void> stop();

  Future<void> setVolume(double volume);
  Future<void> setRate(double rate);
  Future<void> setPitch(double pitch);

  Future<void> dispose();
}
