import 'package:flutter/material.dart';

import '../../core/theme/forge_tokens.dart';

/// Mirrors `.tag-accent` / `.tag-accent-2` / `.tag-neutral` / `.tag-outline`.
enum ForgeTagVariant { accent, accent2, neutral, outline }

/// Ported from `.tag` in the Nocturne styles: 11px label, `0.02em` tracking,
/// `3px 10px` padding, corners at `radius-md * 0.75`.
class ForgeTag extends StatelessWidget {
  const ForgeTag({
    super.key,
    required this.label,
    this.variant = ForgeTagVariant.neutral,
  });

  final String label;
  final ForgeTagVariant variant;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final radius = BorderRadius.circular(tokens.radius.md * 0.75);

    Color background = Colors.transparent;
    Color foreground = tokens.text;
    BoxBorder? border;

    switch (variant) {
      case ForgeTagVariant.accent:
        background = tokens.accentRamp.c800;
        foreground = tokens.accentRamp.c100;
      case ForgeTagVariant.accent2:
        background = tokens.accent2Ramp.c800;
        foreground = tokens.accent2Ramp.c100;
      case ForgeTagVariant.neutral:
        background = tokens.neutralRamp.c800;
        foreground = tokens.neutralRamp.c100;
      case ForgeTagVariant.outline:
        foreground = tokens.accent;
        border = Border.all(color: tokens.accent);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: border,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          letterSpacing: 11 * 0.02,
        ),
      ),
    );
  }
}
