import 'package:flutter/material.dart';

import 'forge_color_ramp.dart';
import 'forge_colors.dart';
import 'forge_radius.dart';
import 'forge_shadows.dart';
import 'forge_spacing.dart';

/// Bundles the Forge design tokens (colors, ramps, spacing, radius, shadows)
/// behind [Theme.of(context).extension]. Widgets should read tokens through
/// this extension rather than importing [ForgeColors]/[ForgeSpacing]/etc.
/// directly, so a future re-theme (e.g. a light mode) is a one-file change.
@immutable
class ForgeTokens extends ThemeExtension<ForgeTokens> {
  const ForgeTokens({
    required this.background,
    required this.surface,
    required this.text,
    required this.accent,
    required this.accent2,
    required this.divider,
    required this.neutralRamp,
    required this.accentRamp,
    required this.accent2Ramp,
    required this.spacing,
    required this.radius,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
  });

  factory ForgeTokens.dark() => ForgeTokens(
    background: ForgeColors.background,
    surface: ForgeColors.surface,
    text: ForgeColors.text,
    accent: ForgeColors.accent,
    accent2: ForgeColors.accent2,
    divider: ForgeColors.divider,
    neutralRamp: ForgeColors.neutral,
    accentRamp: ForgeColors.accentRamp,
    accent2Ramp: ForgeColors.accent2Ramp,
    spacing: ForgeSpacingTokens(),
    radius: ForgeRadiusTokens(),
    shadowSm: ForgeShadows.sm,
    shadowMd: ForgeShadows.md,
    shadowLg: ForgeShadows.lg,
  );

  final Color background;
  final Color surface;
  final Color text;
  final Color accent;
  final Color accent2;
  final Color divider;
  final ForgeColorRamp neutralRamp;
  final ForgeColorRamp accentRamp;
  final ForgeColorRamp accent2Ramp;
  final ForgeSpacingTokens spacing;
  final ForgeRadiusTokens radius;
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowLg;

  @override
  ForgeTokens copyWith({
    Color? background,
    Color? surface,
    Color? text,
    Color? accent,
    Color? accent2,
    Color? divider,
    ForgeColorRamp? neutralRamp,
    ForgeColorRamp? accentRamp,
    ForgeColorRamp? accent2Ramp,
    ForgeSpacingTokens? spacing,
    ForgeRadiusTokens? radius,
    List<BoxShadow>? shadowSm,
    List<BoxShadow>? shadowMd,
    List<BoxShadow>? shadowLg,
  }) {
    return ForgeTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      accent: accent ?? this.accent,
      accent2: accent2 ?? this.accent2,
      divider: divider ?? this.divider,
      neutralRamp: neutralRamp ?? this.neutralRamp,
      accentRamp: accentRamp ?? this.accentRamp,
      accent2Ramp: accent2Ramp ?? this.accent2Ramp,
      spacing: spacing ?? this.spacing,
      radius: radius ?? this.radius,
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
    );
  }

  @override
  ForgeTokens lerp(ThemeExtension<ForgeTokens>? other, double t) {
    // Forge is dark-theme only today; no second token set to interpolate
    // toward, so this is intentionally a no-op until a light theme exists.
    if (other is! ForgeTokens) return this;
    return t < 0.5 ? this : other;
  }
}

/// Non-static wrapper around [ForgeSpacing] so it can live on [ForgeTokens].
class ForgeSpacingTokens {
  const ForgeSpacingTokens();

  double get space1 => ForgeSpacing.space1;
  double get space2 => ForgeSpacing.space2;
  double get space3 => ForgeSpacing.space3;
  double get space4 => ForgeSpacing.space4;
  double get space6 => ForgeSpacing.space6;
  double get space8 => ForgeSpacing.space8;
}

/// Non-static wrapper around [ForgeRadius] so it can live on [ForgeTokens].
class ForgeRadiusTokens {
  const ForgeRadiusTokens();

  double get sm => ForgeRadius.sm;
  double get md => ForgeRadius.md;
  double get lg => ForgeRadius.lg;
  BorderRadius get smRadius => ForgeRadius.smRadius;
  BorderRadius get mdRadius => ForgeRadius.mdRadius;
  BorderRadius get lgRadius => ForgeRadius.lgRadius;
}
