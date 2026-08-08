import 'package:flutter/widgets.dart';

/// Reduced-motion helper: shell/nav animations should collapse to zero
/// duration when the platform's "reduce motion" accessibility setting is
/// on, surfaced to Flutter via [MediaQueryData.disableAnimations].
abstract final class ForgeMotion {
  static Duration duration(BuildContext context, Duration normal) {
    return MediaQuery.of(context).disableAnimations ? Duration.zero : normal;
  }
}
