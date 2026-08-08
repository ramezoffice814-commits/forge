import 'package:flutter/material.dart';

import '../../core/theme/forge_tokens.dart';
import 'forge_input_decoration.dart';

/// A password [TextFormField] with a show/hide toggle. Paste and password
/// -manager autofill are intentionally left enabled — never block them.
/// [isNewPassword] switches the autofill hint between "existing password"
/// (sign-in) and "new password" (sign-up), so platform password managers
/// offer the right behavior (fill vs. suggest-strong-password).
class ForgePasswordField extends StatefulWidget {
  const ForgePasswordField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.textInputAction,
    this.validator,
    this.errorText,
    this.onChanged,
    this.onFieldSubmitted,
    this.autovalidateMode,
    this.isNewPassword = false,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final AutovalidateMode? autovalidateMode;
  final bool isNewPassword;

  @override
  State<ForgePasswordField> createState() => _ForgePasswordFieldState();
}

class _ForgePasswordFieldState extends State<ForgePasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscured,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: [
        widget.isNewPassword
            ? AutofillHints.newPassword
            : AutofillHints.password,
      ],
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      autovalidateMode: widget.autovalidateMode,
      style: TextStyle(color: tokens.text, fontSize: 14),
      cursorColor: tokens.accent,
      decoration: forgeInputDecoration(
        tokens,
        label: widget.label,
        errorText: widget.errorText,
        suffixIcon: Semantics(
          button: true,
          label: _obscured ? 'Show password' : 'Hide password',
          child: IconButton(
            icon: Icon(
              _obscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: tokens.text.withValues(alpha: 0.6),
            ),
            onPressed: () => setState(() => _obscured = !_obscured),
          ),
        ),
      ),
    );
  }
}
