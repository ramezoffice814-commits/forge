import 'package:flutter/material.dart';

import '../../core/theme/forge_colors.dart';
import '../../core/theme/forge_tokens.dart';

/// Shared `.input`-style decoration for [ForgeTextField] and
/// [ForgePasswordField] — one place for the border/fill/error styling both
/// fields need, so it isn't duplicated between them.
InputDecoration forgeInputDecoration(
  ForgeTokens tokens, {
  required String label,
  String? errorText,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: tokens.radius.mdRadius,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: label,
    errorText: errorText,
    errorMaxLines: 3,
    filled: true,
    fillColor: tokens.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    suffixIcon: suffixIcon,
    border: border(tokens.divider),
    enabledBorder: border(tokens.divider),
    focusedBorder: border(tokens.accent, width: 1.5),
    errorBorder: border(ForgeColors.danger),
    focusedErrorBorder: border(ForgeColors.danger, width: 1.5),
  );
}
