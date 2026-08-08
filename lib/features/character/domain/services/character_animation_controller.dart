import 'package:flutter/foundation.dart';

import '../entities/character_state.dart';

/// Drives a character's animation state independent of any specific render
/// technology (Flutter shapes today, Rive later). Notifies listeners
/// whenever [currentState] changes so a render widget can simply rebuild —
/// it never needs a [BuildContext] or a `TickerProvider` itself, which is
/// what keeps implementations unit-testable without pumping a widget tree.
abstract class CharacterAnimationController extends ChangeNotifier {
  CharacterState get currentState;

  /// Requests [state]. For one-shot states (e.g. [CharacterState.entering],
  /// [CharacterState.missionRevealed]) the returned future completes once
  /// that animation has finished playing. For continuous/held states (e.g.
  /// [CharacterState.idle], [CharacterState.speaking]) it completes as soon
  /// as the state has been applied. When [reducedMotion] is true,
  /// implementations should collapse one-shot timing to (near) zero rather
  /// than skip the state change entirely.
  Future<void> play(CharacterState state, {bool reducedMotion = false});

  /// Cancels whatever is in flight without changing [currentState] further.
  /// Any pending [play] future completes immediately once `stop` is called.
  void stop();

  /// Cancels in-flight work and returns to [CharacterState.idle].
  void reset();
}
