import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/character/data/services/placeholder_character_animation_controller.dart';
import 'package:forge/features/character/domain/entities/character_state.dart';

void main() {
  test(
    'continuous states resolve immediately and update currentState',
    () async {
      final controller = PlaceholderCharacterAnimationController();
      await controller.play(CharacterState.idle);
      expect(controller.currentState, CharacterState.idle);
      controller.dispose();
    },
  );

  test('one-shot states resolve after their fixed delay', () async {
    final controller = PlaceholderCharacterAnimationController();
    final stopwatch = Stopwatch()..start();
    await controller.play(CharacterState.missionAccepted);
    stopwatch.stop();

    expect(controller.currentState, CharacterState.missionAccepted);
    expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(400));
    controller.dispose();
  });

  test('reducedMotion collapses one-shot timing to zero', () async {
    final controller = PlaceholderCharacterAnimationController();
    final stopwatch = Stopwatch()..start();
    await controller.play(CharacterState.entering, reducedMotion: true);
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(100));
    controller.dispose();
  });

  test('notifies listeners on every play() and reset()', () async {
    final controller = PlaceholderCharacterAnimationController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.play(CharacterState.idle);
    controller.reset();

    expect(notifications, 2);
    controller.dispose();
  });

  test(
    'a superseding play() makes the earlier one a no-op on completion',
    () async {
      final controller = PlaceholderCharacterAnimationController();

      final first = controller.play(CharacterState.entering);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Supersede before the first one-shot's delay elapses.
      final second = controller.play(CharacterState.missionRevealed);

      await Future.wait([first, second]);
      // The second, later request wins.
      expect(controller.currentState, CharacterState.missionRevealed);
      controller.dispose();
    },
  );

  test(
    'dispose prevents further notifications and further calls do not throw',
    () async {
      final controller = PlaceholderCharacterAnimationController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.play(CharacterState.idle);
      expect(notifications, 1);

      controller.dispose();

      // Must be safe no-ops post-dispose, not throw "used after dispose".
      await controller.play(CharacterState.idle);
      controller.reset();

      expect(notifications, 1);
    },
  );
}
