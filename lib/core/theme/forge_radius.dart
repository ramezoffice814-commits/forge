import 'package:flutter/painting.dart';

/// Corner radii ported from the Nocturne `--radius-*` tokens.
abstract final class ForgeRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 14;

  static const smRadius = BorderRadius.all(Radius.circular(sm));
  static const mdRadius = BorderRadius.all(Radius.circular(md));
  static const lgRadius = BorderRadius.all(Radius.circular(lg));
}
