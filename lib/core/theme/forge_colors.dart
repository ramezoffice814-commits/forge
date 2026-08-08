import 'package:flutter/painting.dart';

import 'forge_color_ramp.dart';

/// Static color values ported 1:1 from the Forge mockup's Nocturne design
/// tokens (`_ds/nocturne-*/styles.css`). Forge is dark-theme only for now —
/// there is no light-theme ramp in the source design.
abstract final class ForgeColors {
  static const background = Color(0xFF161826);
  static const surface = Color(0xFF232532);
  static const text = Color(0xFFE9E9ED);
  static const accent = Color(0xFF9184D9);
  static const accent2 = Color(0xFFA7A1DB);

  /// `color-mix(in srgb, #e9e9ed 16%, transparent)`
  static const divider = Color(0x29E9E9ED);

  /// The mockup's `var(--color-danger, #ef4444)` fallback — Nocturne's
  /// tokens don't define a danger color of their own, so this is it.
  static const danger = Color(0xFFEF4444);

  static const neutral = ForgeColorRamp(
    c100: Color(0xFFF3F5FE),
    c200: Color(0xFFE4E7F5),
    c300: Color(0xFFCFD3E5),
    c400: Color(0xFFB2B6CA),
    c500: Color(0xFF9397AB),
    c600: Color(0xFF75798C),
    c700: Color(0xFF595D6C),
    c800: Color(0xFF3F424D),
    c900: Color(0xFF292B31),
  );

  static const accentRamp = ForgeColorRamp(
    c100: Color(0xFFF5F4FF),
    c200: Color(0xFFE7E5FE),
    c300: Color(0xFFD2CEFD),
    c400: Color(0xFFB5ABFC),
    c500: Color(0xFF968AE0),
    c600: Color(0xFF796CBF),
    c700: Color(0xFF5D5294),
    c800: Color(0xFF423A6A),
    c900: Color(0xFF2B2741),
  );

  static const accent2Ramp = ForgeColorRamp(
    c100: Color(0xFFF5F4FF),
    c200: Color(0xFFE7E5FE),
    c300: Color(0xFFD2CEFD),
    c400: Color(0xFFB5AFE8),
    c500: Color(0xFF9690C9),
    c600: Color(0xFF7972A9),
    c700: Color(0xFF5C5783),
    c800: Color(0xFF423E5D),
    c900: Color(0xFF2B293A),
  );
}
