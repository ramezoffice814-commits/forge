import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'forge_colors.dart';
import 'forge_tokens.dart';

/// Builds the app [ThemeData] from the Forge design tokens. Forge ships
/// dark-theme only, matching the mockup — there is no light variant defined
/// in the source design yet.
abstract final class ForgeTheme {
  static ThemeData dark() {
    final textTheme = _textTheme();
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: ForgeColors.accent,
          brightness: Brightness.dark,
          surface: ForgeColors.background,
          onSurface: ForgeColors.text,
          primary: ForgeColors.accent,
        ).copyWith(
          surfaceContainer: ForgeColors.surface,
          outline: ForgeColors.divider,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ForgeColors.background,
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      dividerColor: ForgeColors.divider,
      extensions: [ForgeTokens.dark()],
    );
  }

  /// Mirrors the mockup's h1–h6 scale: Inter, weight 500 (`--font-heading-weight`),
  /// tight `-0.015em` tracking, `1.12` line height — h6 additionally uppercase
  /// with `+0.08em` tracking (transform applied at the call site, Flutter
  /// [TextStyle] has no text-transform). Body copy is Inter 400, 15px, 1.55.
  ///
  /// `bodySmall` is the smaller body-copy variant used pervasively across
  /// the app for muted/secondary text (unlock reasons, card captions,
  /// notification/settings explanatory copy) — same family/weight/color
  /// convention as [bodyMedium] (Inter 400, [ForgeColors.text] at full
  /// opacity; callers apply `.withValues(alpha: ...)` for the muted look,
  /// exactly like every existing `bodyMedium`/`bodySmall` call site
  /// already does), just one step down in size. Mobile Polish Pass 1:
  /// this role was previously left undefined here, so `ThemeData` silently
  /// merged in Flutter's stock Material3 `bodySmall` (12px, different
  /// line-height/letter-spacing, no relation to this app's own scale) —
  /// every screen using `textTheme.bodySmall` was quietly off-system.
  static TextTheme _textTheme() {
    TextStyle heading(double size, {double trackingEm = -0.015}) {
      return GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w500,
        height: 1.12,
        letterSpacing: size * trackingEm,
        color: ForgeColors.text,
      );
    }

    return TextTheme(
      headlineLarge: heading(42), // h1
      headlineMedium: heading(32), // h2
      headlineSmall: heading(25), // h3
      titleLarge: heading(20), // h4
      titleMedium: heading(16), // h5
      titleSmall: heading(13, trackingEm: 0.08), // h6 (uppercase at call site)
      bodyMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.55,
        color: ForgeColors.text,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: ForgeColors.text,
      ),
    );
  }
}
