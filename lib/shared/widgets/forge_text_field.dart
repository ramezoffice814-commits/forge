import 'package:flutter/material.dart';

import '../../core/theme/forge_tokens.dart';
import 'forge_input_decoration.dart';

/// The design system's single text-input primitive — every plain (non
/// -password) field in the app should use this rather than a bare
/// [TextFormField], so border/fill/error styling never drifts between
/// screens.
class ForgeTextField extends StatelessWidget {
  const ForgeTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.validator,
    this.errorText,
    this.onChanged,
    this.onFieldSubmitted,
    this.autovalidateMode,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final AutovalidateMode? autovalidateMode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      autovalidateMode: autovalidateMode,
      enabled: enabled,
      style: TextStyle(color: tokens.text, fontSize: 14),
      cursorColor: tokens.accent,
      decoration: forgeInputDecoration(
        tokens,
        label: label,
        errorText: errorText,
      ),
    );
  }
}
