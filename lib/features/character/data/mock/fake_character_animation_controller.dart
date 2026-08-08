import 'dart:async';

import '../../domain/entities/character_state.dart';
import '../../domain/services/character_animation_controller.dart';

/// An instant-resolving [CharacterAnimationController] double for tests —
/// same contract as [PlaceholderCharacterAnimationController], but with no
/// delay at all, so controller tests aren't paying real wall-clock time for
/// one-shot animation playback. Records every requested state for
/// assertions on animation-call ordering.
///
/// With [autoComplete] set to false, [play] instead stalls until
/// [completeCurrentPlay] is called — used by golden tests that need to
/// freeze the experience at an exact, otherwise-transient phase (e.g.
/// `incoming`, which the default instant behavior sails straight through).
class FakeCharacterAnimationController extends CharacterAnimationController {
  FakeCharacterAnimationController({this.autoComplete = true});

  final bool autoComplete;

  CharacterState _state = CharacterState.hidden;
  final List<CharacterState> requestedStates = [];
  final List<bool> reducedMotionFlags = [];
  int stopCalls = 0;
  bool disposed = false;
  Completer<void>? _pending;

  @override
  CharacterState get currentState => _state;

  @override
  Future<void> play(CharacterState state, {bool reducedMotion = false}) async {
    if (disposed) return;
    _state = state;
    requestedStates.add(state);
    reducedMotionFlags.add(reducedMotion);
    notifyListeners();

    if (autoComplete) return;
    final completer = Completer<void>();
    _pending = completer;
    return completer.future;
  }

  /// Manually resolves whatever [play] call is currently stalled — only
  /// meaningful when [autoComplete] is false.
  void completeCurrentPlay() {
    final completer = _pending;
    _pending = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  @override
  void stop() {
    stopCalls++;
    completeCurrentPlay();
  }

  @override
  void reset() {
    if (disposed) return;
    _state = CharacterState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    completeCurrentPlay();
    super.dispose();
  }
}
