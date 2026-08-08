import '../../domain/entities/character_state.dart';
import '../../domain/services/character_animation_controller.dart';

/// Flutter-native placeholder engine: no Rive, no continuously repeating
/// tickers. One-shot states resolve after a fixed, short delay (simulating
/// an animation playing out); continuous states resolve immediately. A
/// generation counter makes [stop]/[reset]/a superseding [play] call safe —
/// a stale delayed completion can never resurrect an old state after
/// something newer has already happened.
class PlaceholderCharacterAnimationController
    extends CharacterAnimationController {
  CharacterState _state = CharacterState.hidden;
  int _generation = 0;
  bool _disposed = false;

  static const _oneShotDurations = {
    CharacterState.entering: Duration(milliseconds: 600),
    CharacterState.missionRevealed: Duration(milliseconds: 500),
    CharacterState.missionAccepted: Duration(milliseconds: 450),
    CharacterState.proud: Duration(milliseconds: 500),
    CharacterState.concerned: Duration(milliseconds: 500),
    CharacterState.completed: Duration(milliseconds: 500),
    CharacterState.disappearing: Duration(milliseconds: 500),
  };

  @override
  CharacterState get currentState => _state;

  @override
  Future<void> play(CharacterState state, {bool reducedMotion = false}) async {
    if (_disposed) return;
    _state = state;
    notifyListeners();

    final duration = _oneShotDurations[state];
    if (duration == null) return;

    final generation = ++_generation;
    await Future<void>.delayed(reducedMotion ? Duration.zero : duration);
    if (_disposed || generation != _generation) return;
  }

  @override
  void stop() {
    _generation++;
  }

  @override
  void reset() {
    if (_disposed) return;
    _generation++;
    _state = CharacterState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
