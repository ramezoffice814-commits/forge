import 'package:flutter/material.dart';

import '../../core/theme/forge_tokens.dart';

/// Mirrors the mockup's `.btn-primary` / `.btn-secondary` / `.btn-ghost`.
enum ForgeButtonVariant { primary, secondary, ghost }

/// Ported from `.btn` in the Nocturne styles: transparent fill, accent or
/// divider border depending on [variant], `radius-md` corners, tinted
/// hover/press states mixed from the accent or text color.
class ForgeButton extends StatelessWidget {
  const ForgeButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ForgeButtonVariant.primary,
    this.icon,
    this.minHeight = 44, // accessibility: large touch targets by default
  });

  final String label;
  final VoidCallback? onPressed;
  final ForgeButtonVariant variant;
  final Widget? icon;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final disabled = onPressed == null;

    final Color foreground;
    final Color? borderColor;
    switch (variant) {
      case ForgeButtonVariant.primary:
        foreground = tokens.accent;
        borderColor = tokens.accent;
      case ForgeButtonVariant.secondary:
        foreground = tokens.text;
        borderColor = tokens.divider;
      case ForgeButtonVariant.ghost:
        foreground = tokens.accent;
        borderColor = null;
    }

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: tokens.radius.mdRadius,
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: tokens.radius.mdRadius,
          hoverColor: foreground.withValues(alpha: 0.12),
          splashColor: foreground.withValues(alpha: 0.22),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: tokens.spacing.space2,
                horizontal: tokens.spacing.space3 * 1.2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    SizedBox(width: tokens.spacing.space2),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
