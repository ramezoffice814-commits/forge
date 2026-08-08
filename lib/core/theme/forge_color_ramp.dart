import 'package:flutter/painting.dart';

/// A 100–900 tonal ramp, mirroring the Nocturne design tokens
/// (`--color-{name}-100..900`) from the Forge mockup's `styles.css`.
class ForgeColorRamp {
  const ForgeColorRamp({
    required this.c100,
    required this.c200,
    required this.c300,
    required this.c400,
    required this.c500,
    required this.c600,
    required this.c700,
    required this.c800,
    required this.c900,
  });

  final Color c100;
  final Color c200;
  final Color c300;
  final Color c400;
  final Color c500;
  final Color c600;
  final Color c700;
  final Color c800;
  final Color c900;
}
