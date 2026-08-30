import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_colors.dart';
import 'package:forge/core/theme/forge_theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  group('ForgeTheme.dark bodySmall', () {
    // Mobile Polish Pass 1 regression: bodySmall was previously left
    // undefined, so ThemeData silently merged in Flutter's stock
    // Material3 default (Inter-unrelated font, 12px, different
    // line-height/letter-spacing) instead of this app's own type scale —
    // this is the one place that class of bug can hide again.
    final textTheme = ForgeTheme.dark().textTheme;
    final bodySmall = textTheme.bodySmall!;

    test('uses the Inter font family, same as the rest of the scale', () {
      expect(bodySmall.fontFamily, GoogleFonts.inter().fontFamily);
      expect(bodySmall.fontFamily, textTheme.bodyMedium!.fontFamily);
    });

    test('matches the CAN body-copy weight and base color', () {
      expect(bodySmall.fontWeight, FontWeight.w400);
      expect(bodySmall.color, ForgeColors.text);
    });

    test('is smaller than bodyMedium but not Material3\'s stock 12px', () {
      expect(bodySmall.fontSize, lessThan(textTheme.bodyMedium!.fontSize!));
      expect(bodySmall.fontSize, isNot(12));
      expect(bodySmall.fontSize, 13);
    });

    test('has a comfortable line height, not the Material3 default', () {
      expect(bodySmall.height, 1.4);
    });
  });
}
